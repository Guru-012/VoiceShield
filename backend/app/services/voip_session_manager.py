import io
import json
import numpy as np
import scipy.io.wavfile as wavfile
from typing import Dict, Any, Optional, List
from fastapi import WebSocket

class VoIPSessionManager:
    """
    VoIP Call Session & Real-Time Live Audio Stream Manager.
    Manages WebRTC signaling channels, in-memory audio ring buffers,
    rolling Exponential Moving Average (EMA) AI probabilities, and threat alerts.
    """

    def __init__(self, alpha: float = 0.4):
        self.alpha = alpha  # EMA smoothing factor
        self.signaling_connections: Dict[str, WebSocket] = {}  # client_id -> WebSocket
        self.active_rooms: Dict[str, List[str]] = {}            # room_id -> [client_ids]
        self.call_audio_buffers: Dict[str, bytearray] = {}     # call_id -> PCM bytearray
        self.call_rolling_ema: Dict[str, float] = {}           # call_id -> rolling AI prob float
        self.consecutive_threats: Dict[str, int] = {}          # call_id -> threat count

    # ------------------------------------------------------------------------
    # 1. SIGNALING CONNECTION MANAGEMENT
    # ------------------------------------------------------------------------
    async def connect_client(self, client_id: str, websocket: WebSocket):
        await websocket.accept()
        self.signaling_connections[client_id] = websocket

    def disconnect_client(self, client_id: str):
        if client_id in self.signaling_connections:
            del self.signaling_connections[client_id]
        
        # Clean up client from any active room
        for room_id, clients in list(self.active_rooms.items()):
            if client_id in clients:
                clients.remove(client_id)
                if not clients:
                    del self.active_rooms[room_id]

    async def send_signaling_message(self, recipient_id: str, message: Dict[str, Any]):
        if recipient_id in self.signaling_connections:
            await self.signaling_connections[recipient_id].send_json(message)

    # ------------------------------------------------------------------------
    # 2. CALL & STREAM BUFFER MANAGEMENT
    # ------------------------------------------------------------------------
    def init_call_session(self, call_id: str):
        self.call_audio_buffers[call_id] = bytearray()
        self.call_rolling_ema[call_id] = 0.0
        self.consecutive_threats[call_id] = 0

    def cleanup_call_session(self, call_id: str):
        self.call_audio_buffers.pop(call_id, None)
        self.call_rolling_ema.pop(call_id, None)
        self.consecutive_threats.pop(call_id, None)

    # ------------------------------------------------------------------------
    # 3. LIVE AUDIO CHUNK INGESTION & ROLLING EMA AI EVALUATION
    # ------------------------------------------------------------------------
    def process_audio_chunk(
        self,
        call_id: str,
        audio_chunk_bytes: bytes,
        voice_detector: Any,
        risk_engine: Any,
        sample_rate: int = 16000
    ) -> Optional[Dict[str, Any]]:
        """
        Appends raw audio chunk to the call's buffer.
        When buffer contains >= 2.5 seconds of audio (~80,000 16-bit PCM bytes),
        runs voice_detector.predict(), updates rolling EMA, and returns evaluation payload.
        """
        if call_id not in self.call_audio_buffers:
            self.init_call_session(call_id)

        buffer = self.call_audio_buffers[call_id]
        buffer.extend(audio_chunk_bytes)

        # 2.5 seconds @ 16kHz 16-bit Mono PCM = 16000 * 2.5 * 2 bytes = 80,000 bytes
        min_bytes_threshold = int(sample_rate * 2.5 * 2)

        if len(buffer) < min_bytes_threshold:
            return None  # Accumulating buffer

        # Extract 2.5-second window bytes for analysis
        window_bytes = bytes(buffer[:min_bytes_threshold])
        
        # Slide buffer forward by 1.0 second (~32,000 bytes)
        slide_bytes = int(sample_rate * 1.0 * 2)
        del buffer[:slide_bytes]

        # Convert raw 16-bit PCM bytes to canonical 16kHz Mono WAV bytes for voice_detector
        pcm_array = np.frombuffer(window_bytes, dtype=np.int16)
        wav_buf = io.BytesIO()
        wavfile.write(wav_buf, sample_rate, pcm_array)
        canonical_wav_bytes = wav_buf.getvalue()

        # Run pretrained voice detector inference
        audio_meta = {
            "duration_seconds": 2.5,
            "processed_sample_rate": sample_rate,
            "processed_channels": 1,
            "format": "wav"
        }
        detector_eval = voice_detector.predict(audio_meta, canonical_wav_bytes)

        raw_ai_prob = float(detector_eval.get("ai_probability", 0.0))
        is_dev = bool(detector_eval.get("is_development_mode", True))

        # Calculate Exponential Moving Average (EMA) rolling AI score
        prev_ema = self.call_rolling_ema.get(call_id, 0.0)
        rolling_ema = (self.alpha * raw_ai_prob) + ((1.0 - self.alpha) * prev_ema)
        self.call_rolling_ema[call_id] = round(rolling_ema, 4)

        # Track consecutive high-probability windows to prevent false alarms
        if raw_ai_prob >= 0.65:
            self.consecutive_threats[call_id] += 1
        else:
            self.consecutive_threats[call_id] = max(0, self.consecutive_threats[call_id] - 1)

        threat_triggered = (self.consecutive_threats[call_id] >= 2) or (rolling_ema >= 0.65)

        # Calculate composite risk through existing RiskEngine
        risk_eval = risk_engine.calculate_risk(
            ai_probability=rolling_ema,
            context_score=0.0,
            indicators=["REAL-TIME STREAMING: Live in-app VoIP audio analysis active"],
            is_development_mode=is_dev
        )

        ai_prob = round(rolling_ema, 4)
        authenticity = round(max(0.0, 1.0 - rolling_ema), 4)
        confidence = float(detector_eval.get("voice_confidence", round(max(raw_ai_prob, 1.0 - raw_ai_prob), 4)))
        risk_level = risk_eval.get("risk_level", "DEV_MODE")
        is_ai_generated = bool(rolling_ema >= 0.5 or raw_ai_prob >= 0.5)

        return {
            "call_id": call_id,
            "ai_probability": ai_prob,
            "authenticity": authenticity,
            "confidence": confidence,
            "risk_level": risk_level,
            "is_ai_generated": is_ai_generated,
            "raw_ai_probability": raw_ai_prob,
            "rolling_ai_probability": round(rolling_ema, 4),
            "consecutive_threat_count": self.consecutive_threats[call_id],
            "threat_alert_triggered": threat_triggered,
            "voice_result": detector_eval.get("voice_result", "MODEL_NOT_CONNECTED"),
            "display_title": detector_eval.get("display_title", ""),
            "risk_score": risk_eval.get("risk_score", 0),
            "recommendation": risk_eval.get("recommendation", ""),
            "is_development_mode": is_dev
        }

# Global singleton VoIP Session Manager instance
voip_manager = VoIPSessionManager()
