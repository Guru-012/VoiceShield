import io
import uuid
from concurrent.futures import Future, ThreadPoolExecutor
from datetime import datetime, timezone
from typing import Dict, Any, Optional

import numpy as np
import scipy.io.wavfile as wavfile


class RealtimeSessionManager:
    """
    Real-time Live Audio Detection Session Manager for VoiceShield.

    Responsibilities:
    - Manage live detection sessions
    - Buffer incoming PCM audio
    - Run Wav2Vec2 voice detection
    - Maintain rolling EMA AI probability
    - Run Whisper STT in a background worker
    - Analyze suspicious conversational context
    - Calculate composite risk
    - Generate live threat alerts

    IMPORTANT:
    Whisper transcription is intentionally executed in a
    background thread so that slow CPU inference does not block
    the WebSocket audio-processing loop.
    """

    def __init__(self, alpha: float = 0.4):
        self.alpha = alpha

        # Active sessions.
        self.sessions: Dict[str, Dict[str, Any]] = {}

        # Background workers used for Whisper STT.
        #
        # Two workers allow transcription to happen independently
        # from the WebSocket/audio processing loop.
        self.stt_executor = ThreadPoolExecutor(
            max_workers=2,
            thread_name_prefix="voiceshield-stt",
        )

    # ============================================================
    # CREATE SESSION
    # ============================================================

    def create_session(
        self,
        session_id: Optional[str] = None,
        sample_rate: int = 16000,
    ) -> str:
        """
        Initializes a new real-time detection session.
        """

        sid = (
            session_id
            or f"rs_{uuid.uuid4().hex[:10]}"
        )

        self.sessions[sid] = {
            "session_id": sid,
            "created_at": datetime.now(
                timezone.utc
            ).isoformat(),

            "sample_rate": sample_rate,

            # Main voice-detection buffer.
            "buffer": bytearray(),

            # Separate STT buffer.
            "stt_buffer": bytearray(),

            # Rolling AI score.
            "rolling_ema": 0.0,

            # Threat tracking.
            "consecutive_threats": 0,

            # Audio chunk counter.
            "chunk_index": 0,

            # Latest Whisper transcript.
            "latest_transcript": "",

            # Context analysis.
            "context_score": 0.0,
            "context_indicators": [],

            # Session state.
            "active": True,

            # Background Whisper job.
            "stt_future": None,

            # Number of STT windows submitted.
            "stt_window_index": 0,
        }

        return sid

    # ============================================================
    # GET SESSION
    # ============================================================

    def get_session(
        self,
        session_id: str,
    ) -> Optional[Dict[str, Any]]:
        return self.sessions.get(session_id)

    # ============================================================
    # CLEANUP SESSION
    # ============================================================

    def cleanup_session(
        self,
        session_id: str,
    ):
        """
        Removes session state.

        Any currently running Whisper task is cancelled where
        possible. A running CPU task may finish naturally, but
        it will no longer be used by the removed session.
        """

        session = self.sessions.get(session_id)

        if session:
            future = session.get("stt_future")

            if isinstance(future, Future):
                try:
                    future.cancel()
                except Exception:
                    pass

        self.sessions.pop(
            session_id,
            None,
        )

    # ============================================================
    # BACKGROUND STT WORKER
    # ============================================================

    def _run_stt_worker(
        self,
        stt_service: Any,
        context_analyzer: Any,
        stt_wav_bytes: bytes,
        sample_rate: int,
    ) -> Dict[str, Any]:
        """
        Runs Whisper STT outside the WebSocket processing thread.

        This method must not directly update the session because
        the session may be cleaned up while the worker is running.

        Returns the transcription + context analysis result.
        """

        try:
            # ----------------------------------------------------
            # WHISPER TRANSCRIPTION
            # ----------------------------------------------------

            stt_res = stt_service.transcribe(
                stt_wav_bytes,
                "realtime.wav",
            )

            transcript = (
                stt_res.get(
                    "transcript",
                    "",
                )
                or ""
            ).strip()

            context_score = 0.0
            context_indicators = []

            # ----------------------------------------------------
            # CONTEXT ANALYSIS
            # ----------------------------------------------------

            if (
                context_analyzer is not None
                and transcript
            ):
                try:
                    is_stt_dev = getattr(
                        stt_service,
                        "is_development_mode",
                        True,
                    )

                    context_eval = (
                        context_analyzer.analyze(
                            transcript,
                            is_development_mode=is_stt_dev,
                        )
                    )

                    context_score = float(
                        context_eval.get(
                            "context_score",
                            0.0,
                        )
                    )

                    context_indicators = (
                        context_eval.get(
                            "indicators",
                            [],
                        )
                        or []
                    )

                except Exception as context_error:
                    print(
                        "Notice: Context analysis skipped: "
                        f"{context_error}"
                    )

            return {
                "success": True,
                "transcript": transcript,
                "language": stt_res.get(
                    "language",
                    "en",
                ),
                "confidence": stt_res.get(
                    "confidence",
                    0.0,
                ),
                "context_score": context_score,
                "context_indicators": context_indicators,
                "stt_note": stt_res.get(
                    "stt_note",
                    "",
                ),
            }

        except Exception as e:
            print(
                "Notice: Background STT processing failed: "
                f"{e}"
            )

            return {
                "success": False,
                "transcript": "",
                "language": "en",
                "confidence": 0.0,
                "context_score": 0.0,
                "context_indicators": [],
                "stt_note": str(e),
            }

    # ============================================================
    # CHECK COMPLETED STT
    # ============================================================

    def _update_completed_stt(
        self,
        session: Dict[str, Any],
    ):
        """
        Checks whether the background Whisper job has finished.

        This is deliberately non-blocking.

        If Whisper is still processing, the live audio pipeline
        continues normally.
        """

        future = session.get(
            "stt_future"
        )

        if not isinstance(future, Future):
            return

        if not future.done():
            return

        # Clear future before processing the result.
        session["stt_future"] = None

        try:
            result = future.result()

            if not result.get(
                "success",
                False,
            ):
                return

            transcript = (
                result.get(
                    "transcript",
                    "",
                )
                or ""
            ).strip()

            # Only replace transcript when Whisper actually
            # produced speech.
            if transcript:
                session["latest_transcript"] = transcript

                session["context_score"] = float(
                    result.get(
                        "context_score",
                        0.0,
                    )
                )

                session["context_indicators"] = (
                    result.get(
                        "context_indicators",
                        [],
                    )
                    or []
                )

        except Exception as e:
            print(
                "Notice: Could not read background STT result: "
                f"{e}"
            )

    # ============================================================
    # START BACKGROUND STT
    # ============================================================

    def _start_background_stt(
        self,
        session: Dict[str, Any],
        stt_service: Any,
        context_analyzer: Any,
        stt_window_bytes: bytes,
        sample_rate: int,
    ):
        """
        Starts Whisper in a background worker.

        IMPORTANT:
        If Whisper is already processing a previous window,
        no second job is started. This prevents a backlog of
        Whisper requests that would make transcription appear
        progressively slower.
        """

        existing_future = session.get(
            "stt_future"
        )

        if isinstance(
            existing_future,
            Future,
        ):
            if not existing_future.done():
                return

        try:
            # ----------------------------------------------------
            # CONVERT PCM TO WAV
            # ----------------------------------------------------

            stt_pcm = np.frombuffer(
                stt_window_bytes,
                dtype=np.int16,
            )

            if stt_pcm.size == 0:
                return

            stt_wav_buf = io.BytesIO()

            wavfile.write(
                stt_wav_buf,
                sample_rate,
                stt_pcm,
            )

            stt_wav_bytes = (
                stt_wav_buf.getvalue()
            )

            # ----------------------------------------------------
            # SUBMIT WHISPER TO BACKGROUND THREAD
            # ----------------------------------------------------

            future = self.stt_executor.submit(
                self._run_stt_worker,
                stt_service,
                context_analyzer,
                stt_wav_bytes,
                sample_rate,
            )

            session["stt_future"] = future

            session["stt_window_index"] += 1

        except Exception as e:
            print(
                "Notice: Could not start background STT: "
                f"{e}"
            )

    # ============================================================
    # PROCESS AUDIO CHUNK
    # ============================================================

    def process_audio_chunk(
        self,
        session_id: str,
        audio_chunk_bytes: bytes,
        voice_detector: Any,
        risk_engine: Any,
        stt_service: Any = None,
        context_analyzer: Any = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Processes an incoming real-time PCM audio chunk.

        Voice detection:
            2.5-second window
            1-second slide

        Whisper:
            4-second speech window
            2-second slide

        Whisper is executed asynchronously in a background
        worker so it cannot block incoming WebSocket audio.
        """

        # ========================================================
        # GET SESSION
        # ========================================================

        session = self.get_session(
            session_id
        )

        if not session:
            raise ValueError(
                f"Session '{session_id}' "
                "not found or has been closed."
            )

        if not session.get(
            "active",
            False,
        ):
            return None

        # ========================================================
        # CHECK COMPLETED WHISPER JOB
        # ========================================================

        self._update_completed_stt(
            session
        )

        # ========================================================
        # VALIDATE AUDIO
        # ========================================================

        if not audio_chunk_bytes:
            return None

        # ========================================================
        # BUFFERS
        # ========================================================

        buffer = session["buffer"]
        stt_buffer = session["stt_buffer"]

        buffer.extend(
            audio_chunk_bytes
        )

        stt_buffer.extend(
            audio_chunk_bytes
        )

        sample_rate = int(
            session["sample_rate"]
        )

        # ========================================================
        # VOICE DETECTION WINDOW
        # ========================================================

        # 2.5 seconds:
        #
        # 16000 samples/sec
        # x 2.5 seconds
        # x 2 bytes/sample
        #
        # = 80,000 bytes
        #
        min_bytes_threshold = int(
            sample_rate
            * 2.5
            * 2
        )

        if len(buffer) < min_bytes_threshold:
            # We can still check whether a background STT
            # job completed even when the detection window
            # is not ready.
            return None

        # ========================================================
        # EXTRACT VOICE DETECTION WINDOW
        # ========================================================

        window_bytes = bytes(
            buffer[
                :min_bytes_threshold
            ]
        )

        # ========================================================
        # SLIDE VOICE DETECTION BUFFER
        # ========================================================

        # Slide by 1 second.
        slide_bytes = int(
            sample_rate
            * 1.0
            * 2
        )

        del buffer[
            :slide_bytes
        ]

        session["chunk_index"] += 1

        # ========================================================
        # WHISPER STT WINDOW
        # ========================================================

        # Use 4 seconds of speech for Whisper.
        #
        # A longer window gives Whisper more linguistic context
        # and reduces incorrect words from very short chunks.
        #
        # 16000 x 4 x 2 = 128,000 bytes
        stt_min_bytes = int(
            sample_rate
            * 4.0
            * 2
        )

        if (
            len(stt_buffer)
            >= stt_min_bytes
            and stt_service is not None
        ):
            # ----------------------------------------------------
            # Only submit a new Whisper task if the previous
            # task has finished.
            # ----------------------------------------------------

            existing_future = session.get(
                "stt_future"
            )

            stt_ready = (
                existing_future is None
                or (
                    isinstance(
                        existing_future,
                        Future,
                    )
                    and existing_future.done()
                )
            )

            if stt_ready:
                stt_window_bytes = bytes(
                    stt_buffer[
                        :stt_min_bytes
                    ]
                )

                # ------------------------------------------------
                # Start Whisper asynchronously.
                # ------------------------------------------------

                self._start_background_stt(
                    session=session,
                    stt_service=stt_service,
                    context_analyzer=context_analyzer,
                    stt_window_bytes=stt_window_bytes,
                    sample_rate=sample_rate,
                )

                # ------------------------------------------------
                # Slide STT buffer by 2 seconds.
                #
                # This keeps 2 seconds of overlap between
                # consecutive Whisper windows.
                # ------------------------------------------------

                stt_slide = int(
                    sample_rate
                    * 2.0
                    * 2
                )

                if len(stt_buffer) >= stt_slide:
                    del stt_buffer[
                        :stt_slide
                    ]
                else:
                    stt_buffer.clear()

        # ========================================================
        # CONVERT PCM TO WAV
        # ========================================================

        pcm_array = np.frombuffer(
            window_bytes,
            dtype=np.int16,
        )

        wav_buf = io.BytesIO()

        wavfile.write(
            wav_buf,
            sample_rate,
            pcm_array,
        )

        canonical_wav_bytes = (
            wav_buf.getvalue()
        )

        # ========================================================
        # AI VOICE DETECTION
        # ========================================================

        audio_meta = {
            "duration_seconds": 2.5,
            "processed_sample_rate": sample_rate,
            "processed_channels": 1,
            "format": "wav",
        }

        detector_eval = (
            voice_detector.predict(
                audio_meta,
                canonical_wav_bytes,
            )
        )

        raw_ai_prob = float(
            detector_eval.get(
                "ai_probability",
                0.0,
            )
        )

        is_dev = bool(
            detector_eval.get(
                "is_development_mode",
                True,
            )
        )

        # ========================================================
        # EXPONENTIAL MOVING AVERAGE
        # ========================================================

        prev_ema = float(
            session["rolling_ema"]
        )

        rolling_ema = (
            self.alpha
            * raw_ai_prob
        ) + (
            (1.0 - self.alpha)
            * prev_ema
        )

        session["rolling_ema"] = round(
            rolling_ema,
            4,
        )

        # ========================================================
        # CONSECUTIVE THREAT TRACKING
        # ========================================================

        if raw_ai_prob >= 0.65:
            session[
                "consecutive_threats"
            ] += 1

        else:
            session[
                "consecutive_threats"
            ] = max(
                0,
                session[
                    "consecutive_threats"
                ] - 1,
            )

        threat_triggered = (
            session[
                "consecutive_threats"
            ] >= 2
        ) or (
            rolling_ema >= 0.65
        )

        # ========================================================
        # COMBINE CONTEXT INDICATORS
        # ========================================================

        combined_indicators = list(
            session.get(
                "context_indicators",
                [],
            )
        )

        combined_indicators.append(
            "REAL-TIME STREAMING: "
            "Live audio window evaluated"
        )

        # ========================================================
        # RISK ENGINE
        # ========================================================

        risk_eval = (
            risk_engine.calculate_risk(
                ai_probability=rolling_ema,
                context_score=session.get(
                    "context_score",
                    0.0,
                ),
                indicators=combined_indicators,
                is_development_mode=is_dev,
            )
        )

        # ========================================================
        # FINAL VALUES
        # ========================================================

        ai_probability = round(
            rolling_ema,
            4,
        )

        authenticity = round(
            max(
                0.0,
                1.0 - rolling_ema,
            ),
            4,
        )

        confidence = float(
            detector_eval.get(
                "voice_confidence",
                round(
                    max(
                        raw_ai_prob,
                        1.0 - raw_ai_prob,
                    ),
                    4,
                ),
            )
        )

        risk_level = risk_eval.get(
            "risk_level",
            "DEV_MODE",
        )

        is_ai_generated = bool(
            rolling_ema >= 0.5
            or raw_ai_prob >= 0.5
        )

        # ========================================================
        # RETURN REAL-TIME RESULT
        # ========================================================

        return {
            "session_id": session_id,

            "chunk_index": session[
                "chunk_index"
            ],

            "ai_probability": ai_probability,

            "authenticity": authenticity,

            "confidence": confidence,

            "risk_level": risk_level,

            "is_ai_generated": is_ai_generated,

            "raw_ai_probability": round(
                raw_ai_prob,
                4,
            ),

            "rolling_ai_probability": round(
                rolling_ema,
                4,
            ),

            "threat_alert_triggered": (
                threat_triggered
            ),

            "voice_result": detector_eval.get(
                "voice_result",
                "MODEL_NOT_CONNECTED",
            ),

            "display_title": detector_eval.get(
                "display_title",
                "",
            ),

            # Latest completed Whisper transcript.
            "transcript": session.get(
                "latest_transcript",
                "",
            ),

            "context_score": session.get(
                "context_score",
                0.0,
            ),

            "indicators": session.get(
                "context_indicators",
                [],
            ),

            "timestamp": datetime.now(
                timezone.utc
            ).isoformat(),

            "is_development_mode": is_dev,
        }


# ================================================================
# GLOBAL SINGLETON
# ================================================================

realtime_session_manager = (
    RealtimeSessionManager()
)