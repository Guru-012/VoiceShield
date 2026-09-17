# VoiceShield REST API Specification

Base URL: `http://localhost:8000/api`

> [!NOTE]
> **Development Mode Behavior (`is_development_mode: true`)**  
> When the real PyTorch deepfake model and Whisper STT models are pending integration:
> - `voice_result`: Returns `"MODEL_NOT_CONNECTED"`
> - `display_title`: Returns `"DEVELOPMENT MODE: AI Model Not Connected"`
> - `transcript`: Returns `"Speech-to-text model not connected in development mode."`
> - `demo_data_notice`: Returns explicit notice that interface values are for layout testing only.

---

## Endpoints Summary

### 1. Health Check
`GET /api/health`

Returns operational status and active model engine mode.

**Response `200 OK`:**
```json
{
  "status": "healthy",
  "service": "VoiceShield Core API",
  "version": "1.0.0-phase1",
  "environment": "development",
  "is_development_mode": true,
  "timestamp": "2026-09-10T13:00:00.000000"
}
```

---

### 2. Analyze Audio Clip
`POST /api/analyze`

Uploads an audio file (`.wav`, `.mp3`, `.m4a`), validates format/size, executes preprocessing, runs deepfake detection and speech context analysis, and returns a unified risk assessment.

**Headers:** `Content-Type: multipart/form-data`  
**Body:** `file` (Binary audio data)

**Response `200 OK` (Development Mode):**
```json
{
  "analysis_id": "vs_a1b2c3d4e5",
  "timestamp": "2026-09-10T13:05:00.000000",
  "filename": "sample.wav",
  "voice_result": "MODEL_NOT_CONNECTED",
  "display_title": "DEVELOPMENT MODE: AI Model Not Connected",
  "ai_probability": 0.0,
  "voice_confidence": 0.0,
  "transcript": "Speech-to-text model not connected in development mode.",
  "context_score": 0.0,
  "risk_score": 0,
  "risk_level": "DEV_MODE",
  "indicators": [
    "DEVELOPMENT MODE: Speech-to-text context analysis pending STT plugin"
  ],
  "recommendation": "DEVELOPMENT MODE: AI voice detection model and Speech-to-Text engine are pending plugin. Connect PyTorch deepfake model into VoiceDetectionService for real prediction.",
  "is_development_mode": true,
  "demo_data_notice": "DEMO DATA — NOT A REAL MODEL PREDICTION. These values are for interface testing only and must NOT be interpreted as a real voice-authenticity prediction.",
  "disclaimer": "DEVELOPMENT MODE: AI voice detection model and Speech-to-Text engine are pending plugin. AI voice detection is probabilistic."
}
```

---

### 3. Retrieve Analysis History
`GET /api/history`

Returns a list of recorded analyses.

---

### 4. Delete Analysis Item
`DELETE /api/history/{id}`
