# VoiceShield System Architecture

**Problem Statement ID:** 26104  
**Title:** AI-Powered Real-Time Detection and Prevention of Voice Cloning Impersonation Attacks  
**Platform:** VoiceShield  

---

## 1. High-Level Flow Architecture

```
User Device (Flutter Mobile / Web)
        │
        ├──▶ 1. Static Audio File Upload (`POST /api/analyze`)
        │       │
        │       ├──▶ Audio Preprocessor (Resampling to 16 kHz Mono WAV)
        │       ├──▶ Pretrained Voice Detector (Wav2Vec2 Deepfake Classification)
        │       ├──▶ Phase 4 Speech-to-Text Engine (Local Whisper ASR Model: `openai/whisper-tiny`)
        │       ├──▶ Intent Context Analyzer (Keyword / Psychological Scam Pattern Extraction)
        │       └──▶ Risk Engine (Weighted Risk Score Matrix 0-100)
        │
        └──▶ 2. Phase 3 & 4 Real-Time Voice Streaming (`WS /api/ws/realtime/stream/{session_id}`)
                │
                ├──▶ RealtimeSessionManager (Session Lifecycle & Dual Buffer Allocation)
                ├──▶ Live PCM Audio Ring Buffer (2.5s Window @ 16 kHz Mono PCM, 1s Slide)
                ├──▶ Windowed AI Model Prediction (Wav2Vec2 Deepfake Voice Classifier)
                ├──▶ Periodic Whisper STT & Context Analysis (5.0s Audio Windows)
                ├──▶ Exponential Moving Average Smoothing (EMA Rolling AI Probability, α=0.4)
                └──▶ Real-Time JSON Push (`ai_probability`, `authenticity`, `confidence`, `transcript`, `context_score`, `indicators`, `risk_level`, `is_ai_generated`)
```

---

## 2. Component Layer Responsibilities

### Frontend (`frontend/`)
- Built with **Flutter Material 3** cybersecurity dark theme styling.
- `ApiService`: Standard HTTP REST client for health checks, static file upload analysis (`/api/analyze`), and history.
- `RealtimeVoiceService`: Manages live streaming detection sessions over WebSockets (`/api/realtime/session` and `/api/ws/realtime/stream/{session_id}`).
- `VoIPService`: WebRTC signaling exchange and call session audio streaming.

### Backend (`backend/`)
- Built with **Python FastAPI**.
- Modular services:
  - `AudioProcessor`: Resampling, channel conversion, and duration validation.
  - `VoiceDetectionService`: Hugging Face `garystafford/wav2vec2-deepfake-voice-detector` pipeline on CPU.
  - `SpeechToTextService`: Local Hugging Face Whisper ASR pipeline (`openai/whisper-tiny`) running offline on CPU.
  - `ContextAnalyzer`: Rule-based regex keyword engine extracting 5 scam categories (`financial_request`, `otp_request`, `urgency_detected`, `impersonation_detected`, `secrecy_coercion`).
  - `RealtimeSessionManager`: Dual-buffered session tracking, sliding chunk buffering, periodic STT, windowed evaluation, and EMA score calculation.
  - `VoIPSessionManager`: WebRTC peer signaling and VoIP call stream manager.
  - `RiskEngine`: Weighted threat evaluation combining voice deepfake probability and context risk score.

---

## 3. Phase 4 Speech-to-Text & Context Analysis Architecture

### Local Whisper ASR Model
- **Model**: `openai/whisper-tiny` (Hugging Face Transformers ASR pipeline).
- **Execution**: Runs completely offline on CPU (`device=-1`) without third-party paid APIs or cloud dependencies.
- **Input**: In-memory float32 normalized audio arrays from canonical 16 kHz Mono WAV audio.
- **Output**: Real transcript text, detected language (`"en"`), and confidence score ($0.0 - 1.0$).

### Suspicious Context Categories Detected
1. **Financial Requests**: Transfer demands, account numbers, UPI, GPay, cash, wire transfer.
2. **OTP / Credential Harvesting**: OTP codes, passwords, PINs, CVV codes.
3. **High-Pressure Urgency**: Emergency claims, immediate action demands, hurry tactics.
4. **Authority Impersonation**: Bank managers, police, crime branch, CBI, government officials.
5. **Secrecy & Coercion**: Demands not to inform family/banks, orders to stay on line.
