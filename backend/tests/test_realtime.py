import json
import numpy as np
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def create_raw_pcm_chunk(duration_sec: float = 1.0, sample_rate: int = 16000) -> bytes:
    """
    Generates raw 16-bit 16kHz Mono PCM audio bytes for streaming tests.
    """
    num_samples = int(sample_rate * duration_sec)
    t = np.linspace(0, duration_sec, num_samples, endpoint=False)
    sine_wave = (0.5 * np.sin(2 * np.pi * 440 * t) * 32767).astype(np.int16)
    return sine_wave.tobytes()

def test_realtime_session_lifecycle():
    """
    Tests REST API endpoints for real-time session creation and clean-up.
    """
    # 1. Create real-time session
    response = client.post("/api/realtime/session")
    assert response.status_code == 200
    data = response.json()
    assert "session_id" in data
    assert data["status"] == "active"
    session_id = data["session_id"]

    # 2. Delete/cleanup active session
    del_res = client.delete(f"/api/realtime/session/{session_id}")
    assert del_res.status_code == 200
    assert del_res.json()["status"] == "success"

    # 3. Verify session was deleted
    del_res_again = client.delete(f"/api/realtime/session/{session_id}")
    assert del_res_again.status_code == 404

def test_realtime_websocket_invalid_session():
    """
    Tests error handling when connecting to WebSocket with non-existent session ID.
    """
    with client.websocket_connect("/api/ws/realtime/stream/non_existent_session_id") as ws:
        msg = ws.receive_json()
        assert msg["type"] == "error"
        assert "Invalid or non-existent" in msg["message"]

def test_realtime_websocket_streaming_detection():
    """
    Tests live audio chunk streaming over WebSocket and verifies structured predictions:
    ai_probability, authenticity, confidence, risk_level, and is_ai_generated.
    """
    # 1. Create real-time detection session
    res = client.post("/api/realtime/session")
    assert res.status_code == 200
    session_id = res.json()["session_id"]

    # 2. Connect to WebSocket real-time audio detection stream
    with client.websocket_connect(f"/api/ws/realtime/stream/{session_id}") as ws_stream:
        # Handshake confirmation message
        connected_msg = ws_stream.receive_json()
        assert connected_msg["type"] == "session_connected"
        assert connected_msg["session_id"] == session_id

        # Stream 3 x 1.0-second PCM audio chunks (total 3.0s audio > 2.5s window)
        for _ in range(3):
            chunk = create_raw_pcm_chunk(duration_sec=1.0)
            ws_stream.send_bytes(chunk)

        # Receive real-time detection update
        update_msg = ws_stream.receive_json()
        assert update_msg["type"] == "realtime_detection_update"
        d = update_msg["data"]

        # Validate mandatory Phase 3 structured detection output fields
        assert d["session_id"] == session_id
        assert d["chunk_index"] >= 1
        assert "ai_probability" in d and 0.0 <= d["ai_probability"] <= 1.0
        assert "authenticity" in d and 0.0 <= d["authenticity"] <= 1.0
        assert "confidence" in d and 0.0 <= d["confidence"] <= 1.0
        assert d["risk_level"] in ["LOW", "MEDIUM", "HIGH", "DEV_MODE"]
        assert isinstance(d["is_ai_generated"], bool)
        assert "raw_ai_probability" in d
        assert "rolling_ai_probability" in d
        assert "threat_alert_triggered" in d
        assert "voice_result" in d
        assert "display_title" in d
