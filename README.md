# VoiceShield 🛡️

**AI-Powered Real-Time Detection and Prevention of Voice Cloning Impersonation Attacks**  
*Smart India Hackathon (SIH) 2026 — Problem Statement ID: 26104*

VoiceShield is a full-stack cybersecurity mobile and web application designed to protect citizens, enterprises, and financial institutions against AI-generated voice cloning, deepfake imposter calls, and financial fraud.

---

## 🛡️ Phase 1 Development Mode Safeguards

To prevent placeholder development data from being mistaken for real AI predictions during early interface testing:
- **No Misleading Detection Titles**: The system displays **"DEVELOPMENT MODE: AI Model Not Connected"** instead of claiming "REAL VOICE DETECTED" or "POSSIBLY AI-GENERATED".
- **No Fake Transcripts**: Uploaded audio returns *"Speech-to-text model not connected in development mode."*
- **Explicit Demo Data Notices**: UI layout meters and scores carry the explicit label *"DEMO DATA — NOT A REAL MODEL PREDICTION. These values are for interface testing only and must NOT be interpreted as a real voice-authenticity prediction."*
- **Prominent Development Banner**: The Result Screen features an un-missable warning banner highlighting development mode active status.

---

## 🏗️ Project Structure

```
VoiceShield/
├── frontend/             # Flutter Web/Mobile Application
│   ├── lib/
│   │   ├── theme/        # Material 3 Cybersecurity Design System
│   │   ├── models/       # AnalysisResult data models
│   │   ├── services/     # REST ApiService HTTP client
│   │   └── screens/      # Splash, Home, Upload, Analysis, Result, History, Tips, Settings
│   └── pubspec.yaml
│
├── backend/              # Python FastAPI Application
│   ├── app/
│   │   ├── main.py       # FastAPI Entrypoint & CORS setup
│   │   ├── api/          # Endpoints (/health, /analyze, /history)
│   │   ├── services/     # AudioProcessor, VoiceDetectionService, SpeechToText, ContextAnalyzer, RiskEngine
│   │   ├── schemas/      # Pydantic data validation schemas
│   │   └── database/     # SQLite database & SQLAlchemy models
│   ├── tests/            # Pytest suite
│   └── requirements.txt
│
├── ai/                   # Model binaries, training scripts, & dataset hooks
├── docs/                 # Architecture, REST API, & Model plugin documentation
└── README.md
```

---

## 🚀 How to Run & Verify Phase 1

### Step 1: Start FastAPI Backend
```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```
- API Server: `http://localhost:8000`
- Interactive OpenAPI Docs: `http://localhost:8000/docs`

#### Run Automated Tests:
```bash
cd backend
python -m pytest
```
*(Result: 6 passed)*

---

### Step 2: Launch Flutter Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

#### Run Code Analysis:
```bash
cd frontend
flutter analyze
```
*(Result: No issues found!)*

---

## 🗺️ Roadmap to Phase 2 & Beyond

- **Phase 2**: Real-time microphone audio recording integration & waveform visualization.
- **Phase 3**: Integration of trained PyTorch deepfake voice detection model binary (AASIST / WaveFake) into `VoiceDetectionService`.
- **Phase 4**: Local Whisper STT model integration into `SpeechToTextService`.
- **Phase 5**: Advanced LLM context reasoning engine & PDF report generation.
