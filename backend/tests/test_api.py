import io
import pytest
import numpy as np
import scipy.io.wavfile as wavfile
from fastapi.testclient import TestClient
from app.main import app
from app.services.context_analyzer import ContextAnalyzer
from app.services.risk_engine import RiskEngine

client = TestClient(app)

def create_synthetic_wav(duration_sec: float = 3.0, sample_rate: int = 44100, channels: int = 2, silent: bool = False) -> bytes:
    """
    Helper utility generating valid WAV audio bytes for testing.
    """
    num_samples = int(sample_rate * duration_sec)
    if silent:
        data = np.zeros((num_samples, channels), dtype=np.int16)
    else:
        # Generate 440 Hz sine wave tone with random noise
        t = np.linspace(0, duration_sec, num_samples, endpoint=False)
        sine_wave = (0.5 * np.sin(2 * np.pi * 440 * t) * 32767).astype(np.int16)
        if channels == 1:
            data = sine_wave
        else:
            data = np.column_stack((sine_wave, sine_wave))

    buf = io.BytesIO()
    wavfile.write(buf, sample_rate, data)
    return buf.getvalue()

def test_health_endpoint():
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "is_development_mode" in data

def test_analyze_invalid_file_extension():
    files = {"file": ("test.txt", io.BytesIO(b"dummy text"), "text/plain")}
    response = client.post("/api/analyze", files=files)
    assert response.status_code == 400
    assert "Unsupported audio format" in response.json()["detail"]

def test_analyze_too_short_audio():
    # 1.0 second WAV file (< 2.0s minimum threshold)
    short_wav = create_synthetic_wav(duration_sec=1.0)
    files = {"file": ("short.wav", io.BytesIO(short_wav), "audio/wav")}
    response = client.post("/api/analyze", files=files)
    assert response.status_code == 400
    assert "Audio is too short" in response.json()["detail"]

def test_analyze_silent_audio():
    # 3.0 second silent WAV file
    silent_wav = create_synthetic_wav(duration_sec=3.0, silent=True)
    files = {"file": ("silent.wav", io.BytesIO(silent_wav), "audio/wav")}
    response = client.post("/api/analyze", files=files)
    assert response.status_code == 400
    assert "No usable speech audio" in response.json()["detail"]

def test_audio_process_endpoint_valid():
    # 4.0 second 44.1kHz Stereo WAV
    wav_bytes = create_synthetic_wav(duration_sec=4.0, sample_rate=44100, channels=2)
    files = {"file": ("test_stereo.wav", io.BytesIO(wav_bytes), "audio/wav")}
    response = client.post("/api/audio/process", files=files)
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    q = data["audio_quality"]
    assert q["processed_sample_rate"] == 16000
    assert q["processed_channels"] == 1
    assert q["processing_status"] == "READY_FOR_MODEL"
    assert q["duration_seconds"] == 4.0

def test_analyze_valid_audio_upload():
    wav_bytes = create_synthetic_wav(duration_sec=3.0)
    files = {"file": ("sample.wav", io.BytesIO(wav_bytes), "audio/wav")}
    response = client.post("/api/analyze", files=files)
    assert response.status_code == 200
    data = response.json()
    
    assert "analysis_id" in data
    assert "is_development_mode" in data
    assert "voice_result" in data
    assert "display_title" in data
    assert data["audio_quality"]["processed_sample_rate"] == 16000
    assert data["audio_quality"]["processed_channels"] == 1
    if not data["is_development_mode"]:
        assert data["voice_result"] in ["REAL_VOICE", "POSSIBLY_AI_GENERATED", "AI_VOICE_DETECTED"]
        assert "ai_probability" in data
        assert "voice_confidence" in data
    else:
        assert data["voice_result"] in ["MODEL_NOT_CONNECTED", "INFERENCE_ERROR"]


def test_context_analyzer():
    analyzer = ContextAnalyzer()
    res = analyzer.analyze("Send 50000 rupees immediately to bank account and do not tell anyone.", is_development_mode=False)
    assert res["flags"]["financial_request"] is True
    assert res["flags"]["urgency_detected"] is True
    assert res["flags"]["secrecy_coercion"] is True

def test_risk_engine():
    engine = RiskEngine()
    res_dev = engine.calculate_risk(0.9, 0.8, ["Test"], is_development_mode=True)
    assert res_dev["risk_level"] == "DEV_MODE"
