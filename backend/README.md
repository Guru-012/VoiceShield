# VoiceShield FastAPI Backend Service

FastAPI REST backend for real-time AI voice impersonation detection, speech transcription, context indicator extraction, and composite risk calculation.

---

## Quick Start

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Run API Server
```bash
uvicorn app.main:app --reload --port 8000
```

### 3. API Interactive Documentation
- OpenAPI Swagger UI: [http://localhost:8000/docs](http://localhost:8000/docs)
- ReDoc UI: [http://localhost:8000/redoc](http://localhost:8000/redoc)

### 4. Run Pytest Test Suite
```bash
python -m pytest
```

---

## Directory Overview

```
backend/
├── app/
│   ├── main.py                # FastAPI entry point & CORS
│   ├── api/
│   │   └── endpoints.py       # REST routes (/health, /analyze, /history)
│   ├── services/
│   │   ├── audio_processor.py # Resampling & mono format validation
│   │   ├── voice_detector.py  # Modular VoiceDetectionService & model plugin
│   │   ├── speech_to_text.py  # Whisper STT integration interface
│   │   ├── context_analyzer.py# Scam intent & urgency keyword extraction
│   │   └── risk_engine.py     # Composite score & risk level calculation
│   ├── schemas/
│   │   └── analysis.py        # Pydantic request/response schemas
│   └── database/
│       ├── database.py        # SQLite engine session setup
│       └── models.py          # AnalysisRecord SQLAlchemy model
└── tests/
    └── test_api.py            # Automated API & service tests
```
