import io
import pytest
import numpy as np
import scipy.io.wavfile as wavfile
from fastapi.testclient import TestClient
from app.main import app
from app.services.speech_to_text import SpeechToTextService
from app.services.context_analyzer import ContextAnalyzer
from app.services.risk_engine import RiskEngine

client = TestClient(app)

def create_synthetic_wav(duration_sec: float = 3.0, sample_rate: int = 16000) -> bytes:
    """
    Generates a valid 16kHz Mono WAV file with a audible sine tone for STT testing.
    """
    num_samples = int(sample_rate * duration_sec)
    t = np.linspace(0, duration_sec, num_samples, endpoint=False)
    sine_wave = (0.5 * np.sin(2 * np.pi * 440 * t) * 32767).astype(np.int16)
    
    buf = io.BytesIO()
    wavfile.write(buf, sample_rate, sine_wave)
    return buf.getvalue()

def test_stt_service_initialization_and_transcription():
    """
    Tests initialization of local Whisper STT service and transcription output structure.
    """
    stt = SpeechToTextService()
    assert stt.model_name == "openai/whisper-tiny"
    
    wav_bytes = create_synthetic_wav(duration_sec=3.0)
    res = stt.transcribe(wav_bytes, "synthetic_test.wav")

    assert "transcript" in res
    assert isinstance(res["transcript"], str)
    assert "language" in res
    assert "confidence" in res
    assert isinstance(res["confidence"], float)
    assert "is_development_mode" in res
    assert isinstance(res["is_development_mode"], bool)

def test_context_analyzer_scam_keywords():
    """
    Tests ContextAnalyzer keyword regular expression matching across all 5 scam categories.
    """
    analyzer = ContextAnalyzer()

    # 1. Financial Request + Urgency
    res1 = analyzer.analyze(
        "Please transfer 50000 rupees to bank account immediately.",
        is_development_mode=False
    )
    assert res1["flags"]["financial_request"] is True
    assert res1["flags"]["urgency_detected"] is True
    assert res1["context_score"] >= 0.45
    assert any("financial" in ind.lower() for ind in res1["indicators"])

    # 2. OTP / Credential Harvesting + Urgency
    res2 = analyzer.analyze(
        "Give me your OTP verification code right now.",
        is_development_mode=False
    )
    assert res2["flags"]["otp_request"] is True
    assert res2["flags"]["urgency_detected"] is True

    # 3. Authority Impersonation + Secrecy Coercion
    res3 = analyzer.analyze(
        "I am a police officer from crime branch. Keep this confidential and do not tell anyone.",
        is_development_mode=False
    )
    assert res3["flags"]["impersonation_detected"] is True
    assert res3["flags"]["secrecy_coercion"] is True

def test_risk_engine_otp_harvesting_elevates_risk():
    """
    Tests that an OTP harvesting request elevates risk score and level even when voice is real (0% AI).
    """
    engine = RiskEngine()
    
    # Real voice (0% AI) with OTP harvesting indicator
    res = engine.calculate_risk(
        ai_probability=0.0,
        context_score=0.50,
        indicators=["Attempt to harvest OTP / security credentials"],
        is_development_mode=False
    )
    
    assert res["risk_score"] >= 60
    assert res["risk_level"] in ["MEDIUM", "HIGH"]

def test_risk_engine_otp_and_financial_returns_high_risk():
    """
    Tests that combined OTP and Financial demands produce HIGH risk even with 0% AI voice probability.
    """
    engine = RiskEngine()
    
    res = engine.calculate_risk(
        ai_probability=0.0,
        context_score=0.90,
        indicators=[
            "Attempt to harvest OTP / security credentials",
            "Urgent financial transfer request detected"
        ],
        is_development_mode=False
    )
    
    assert res["risk_score"] >= 85
    assert res["risk_level"] == "HIGH"

def test_analyze_endpoint_integration_with_stt():
    """
    Tests /api/analyze endpoint returning transcript and context evaluation.
    """
    wav_bytes = create_synthetic_wav(duration_sec=3.0)
    files = {"file": ("test_stt_sample.wav", io.BytesIO(wav_bytes), "audio/wav")}
    response = client.post("/api/analyze", files=files)
    assert response.status_code == 200
    data = response.json()

    assert "transcript" in data
    assert isinstance(data["transcript"], str)
    assert "context_score" in data
    assert isinstance(data["context_score"], float)
    assert "indicators" in data
    assert isinstance(data["indicators"], list)
    assert "risk_score" in data
    assert "voice_result" in data
