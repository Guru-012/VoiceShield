import io
from typing import Dict, Any, Optional

import numpy as np
import scipy.io.wavfile as wavfile

try:
    import torch
    from transformers import pipeline

    HAS_TRANSFORMERS = True
except ImportError:
    HAS_TRANSFORMERS = False


class SpeechToTextService:
    """
    VoiceShield Speech-to-Text Service.

    Uses Whisper locally for speech recognition.

    Whisper automatically detects the spoken language.
    """

    DEFAULT_MODEL_NAME = "openai/whisper-tiny"

    # Keep automatic language detection.
    # This was the configuration that was recognizing speech.
    TARGET_LANGUAGE = None

    def __init__(
        self,
        model_name_or_path: Optional[str] = None,
    ):
        self.model_name = (
            model_name_or_path
            or self.DEFAULT_MODEL_NAME
        )

        self.pipe = None
        self.is_development_mode = True
        self.model_load_error: Optional[str] = None

        self._load_model()

    # ============================================================
    # LOAD MODEL
    # ============================================================

    def _load_model(self):
        if not HAS_TRANSFORMERS:
            self.model_load_error = (
                "PyTorch or Transformers libraries "
                "are not installed."
            )

            self.is_development_mode = True
            return

        try:
            self.pipe = pipeline(
                "automatic-speech-recognition",
                model=self.model_name,
                device=-1,
            )

            self.is_development_mode = False
            self.model_load_error = None

            print(
                f"Successfully loaded real Whisper STT model: "
                f"'{self.model_name}'"
            )

            print(
                "Whisper automatic language detection enabled"
            )

        except Exception as e:
            self.is_development_mode = True

            self.model_load_error = (
                f"Whisper STT model load failed for "
                f"'{self.model_name}': {str(e)}"
            )

            print(self.model_load_error)

    # ============================================================
    # TRANSCRIBE
    # ============================================================

    def transcribe(
        self,
        canonical_wav_bytes: bytes,
        filename: str,
    ) -> Dict[str, Any]:

        # --------------------------------------------------------
        # CHECK MODEL
        # --------------------------------------------------------

        if (
            self.is_development_mode
            or self.pipe is None
        ):
            return {
                "transcript": "",
                "language": "auto",
                "confidence": 0.0,
                "is_development_mode": True,
                "stt_note": (
                    self.model_load_error
                    or "STT model not connected."
                ),
            }

        try:
            # ----------------------------------------------------
            # READ WAV
            # ----------------------------------------------------

            sr, int_data = wavfile.read(
                io.BytesIO(canonical_wav_bytes)
            )

            if int_data.size == 0:
                return {
                    "transcript": "",
                    "language": "auto",
                    "confidence": 0.0,
                    "is_development_mode": False,
                    "stt_note": "Empty audio data.",
                }

            # ----------------------------------------------------
            # CONVERT TO MONO
            # ----------------------------------------------------

            if len(int_data.shape) > 1:
                int_data = np.mean(
                    int_data,
                    axis=1,
                )

            # ----------------------------------------------------
            # CONVERT AUDIO TO FLOAT32
            # ----------------------------------------------------

            if int_data.dtype == np.int16:

                float_audio = (
                    int_data.astype(np.float32)
                    / 32768.0
                )

            elif int_data.dtype == np.int32:

                float_audio = (
                    int_data.astype(np.float32)
                    / 2147483648.0
                )

            elif int_data.dtype == np.uint8:

                float_audio = (
                    int_data.astype(np.float32)
                    - 128.0
                ) / 128.0

            else:

                float_audio = int_data.astype(
                    np.float32
                )

            # ----------------------------------------------------
            # CLEAN AUDIO
            # ----------------------------------------------------

            float_audio = np.nan_to_num(
                float_audio,
                nan=0.0,
                posinf=0.0,
                neginf=0.0,
            )

            # ----------------------------------------------------
            # WHISPER
            # ----------------------------------------------------
            #
            # Keep the original working configuration.
            # Do NOT force English.
            # Do NOT add condition_on_previous_text here.
            # ----------------------------------------------------

            result = self.pipe(
                {
                    "raw": float_audio,
                    "sampling_rate": sr,
                },
                generate_kwargs={
                    "task": "transcribe",
                },
            )

            # ----------------------------------------------------
            # EXTRACT RESULT
            # ----------------------------------------------------

            text = ""
            detected_language = "auto"

            if isinstance(result, dict):

                text = result.get(
                    "text",
                    "",
                ).strip()

                detected_language = result.get(
                    "language",
                    "auto",
                )

            elif isinstance(result, str):

                text = result.strip()

            elif isinstance(result, list):

                if len(result) > 0:

                    first = result[0]

                    if isinstance(first, dict):

                        text = first.get(
                            "text",
                            "",
                        ).strip()

                        detected_language = (
                            first.get(
                                "language",
                                "auto",
                            )
                        )

                    else:

                        text = str(first).strip()

            # ----------------------------------------------------
            # NORMALIZE LANGUAGE
            # ----------------------------------------------------

            if not detected_language:
                detected_language = "auto"

            detected_language = str(
                detected_language
            )

            # ----------------------------------------------------
            # CLEAN TRANSCRIPT
            # ----------------------------------------------------

            text = " ".join(
                text.split()
            )

            # ----------------------------------------------------
            # RETURN RESULT
            # ----------------------------------------------------

            return {
                "transcript": text,
                "language": detected_language,
                "confidence": (
                    0.90
                    if text
                    else 0.0
                ),
                "is_development_mode": False,
                "stt_note": (
                    "Whisper STT active with "
                    "automatic language detection"
                ),
            }

        except Exception as exc:

            print(
                "Error during Whisper STT transcription: "
                f"{exc}"
            )

            return {
                "transcript": "",
                "language": "auto",
                "confidence": 0.0,
                "is_development_mode": False,
                "stt_note": (
                    f"Transcription error: {str(exc)}"
                ),
            }