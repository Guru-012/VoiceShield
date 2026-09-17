import io
import json
import numpy as np
import pytest
import scipy.io.wavfile as wavfile
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def create_raw_pcm_chunk(duration_sec: float = 1.0, sample_rate: int = 16000) -> bytes:
    """
    Generates raw 16-bit PCM audio bytes for streaming tests.
    """
    num_samples = int(sample_rate * duration_sec)
    t = np.linspace(0, duration_sec, num_samples, endpoint=False)
    sine_wave = (0.5 * np.sin(2 * np.pi * 440 * t) * 32767).astype(np.int16)
    return sine_wave.tobytes()

def test_voip_signaling_websocket():
    """
    Tests WebRTC signaling relay between user_a and user_b.
    """
    with client.websocket_connect("/api/ws/voip/signal/user_a") as ws_a:
        with client.websocket_connect("/api/ws/voip/signal/user_b") as ws_b:
            # User A joins room 101
            ws_a.send_json({"type": "join_room", "room_id": "room_101"})
            ack_a = ws_a.receive_json()
            assert ack_a["type"] == "room_joined"
            assert ack_a["room_id"] == "room_101"

            # User B joins room 101
            ws_b.send_json({"type": "join_room", "room_id": "room_101"})
            ack_b = ws_b.receive_json()
            assert ack_b["type"] == "room_joined"
            assert ack_b["room_id"] == "room_101"

            # User A sends WebRTC SDP offer to User B
            offer_payload = {
                "type": "offer",
                "target_id": "user_b",
                "sdp": "v=0\r\no=- 123456 2 IN IP4 127.0.0.1..."
            }
            ws_a.send_json(offer_payload)

            # User B receives forwarded SDP offer
            relayed_msg = ws_b.receive_json()
            assert relayed_msg["type"] == "offer"
            assert relayed_msg["sender_id"] == "user_a"
            assert relayed_msg["sdp"] == offer_payload["sdp"]

def test_voip_audio_stream_websocket():
    """
    Tests live PCM audio streaming and real-time AI threat evaluation over WebSocket.
    """
    with client.websocket_connect("/api/ws/voip/stream/call_999/user_a") as ws_stream:
        # Send 3 x 1.0-second PCM chunks (total 3.0s audio > 2.5s window threshold)
        for _ in range(3):
            chunk = create_raw_pcm_chunk(duration_sec=1.0)
            ws_stream.send_bytes(chunk)

        # Receive real-time AI threat evaluation update
        threat_msg = ws_stream.receive_json()
        assert threat_msg["type"] == "ai_threat_update"
        data = threat_msg["data"]
        assert data["call_id"] == "call_999"
        assert "rolling_ai_probability" in data
        assert "threat_alert_triggered" in data
        assert "risk_score" in data
        assert "voice_result" in data
