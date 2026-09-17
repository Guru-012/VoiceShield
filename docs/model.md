# AI Voice Impersonation Model Integration Guide

> [!WARNING]
> **CURRENT DETECTOR STATUS: DEVELOPMENT PLACEHOLDER**
> 
> The current system operates strictly in **DEVELOPMENT MODE** (`is_development_mode: true`).
> - **Real AI Voice Impersonation Model**: Pending Phase 3 PyTorch binary model integration.
> - **Real Speech-to-Text Model**: Pending Phase 4 Whisper STT model integration.
> - **Current Behavior**: Endpoints return explicit notices (`"DEVELOPMENT MODE: AI Model Not Connected"`, `"Speech-to-text model not connected in development mode."`) so mock pipelines are never mistaken for real machine learning predictions.

---

## 1. Overview
VoiceShield uses a modular architecture for AI Voice Cloning Impersonation Detection.

In Phase 3, a trained deep learning binary model (e.g. PyTorch / ONNX model trained on ASVspoof 2019/2021 or WaveFake datasets) is plugged directly into `VoiceDetectionService`.

---

## 2. Model Plug-in Location

File: [backend/app/services/voice_detector.py](file:///C:/Users/tejas/.gemini/antigravity/scratch/VoiceShield/backend/app/services/voice_detector.py)

### How to plug in your PyTorch / Librosa trained model:

```python
import torch
import librosa
import numpy as np
from typing import Dict, Any

class VoiceDetectionService:
    def __init__(self, model_path: str = "ai/models/deepfake_detector.pth"):
        self.model_path = model_path
        # 1. Load trained PyTorch weights
        self.model = torch.load(model_path, map_location=torch.device('cpu'))
        self.model.eval()
        # 2. Set development mode flag to False to activate production predictions
        self.is_development_mode = False

    def predict(self, audio_metadata: Dict[str, Any], audio_bytes: bytes) -> Dict[str, Any]:
        # 3. Extract Spectrogram / MFCC features using Librosa
        y, sr = librosa.load(io.BytesIO(audio_bytes), sr=16000, mono=True)
        mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=40)
        tensor_input = torch.tensor(mfcc).unsqueeze(0).float()
        
        # 4. Perform inference
        with torch.no_grad():
            outputs = self.model(tensor_input)
            probs = torch.softmax(outputs, dim=1)[0]
            ai_prob = probs[1].item()  # Class index 1 = Synthetic / Cloned Voice

        voice_result = "POSSIBLY_AI_GENERATED" if ai_prob > 0.5 else "REAL_VOICE"

        return {
            "voice_result": voice_result,
            "display_title": "POSSIBLY AI-GENERATED VOICE DETECTED" if ai_prob > 0.5 else "REAL VOICE DETECTED",
            "ai_probability": round(ai_prob, 2),
            "voice_confidence": round(max(probs[0].item(), probs[1].item()), 2),
            "is_development_mode": False,
            "detector_note": "Trained PyTorch model inference executed."
        }
```

---

## 3. Speech-to-Text Model Integration

File: [backend/app/services/speech_to_text.py](file:///C:/Users/tejas/.gemini/antigravity/scratch/VoiceShield/backend/app/services/speech_to_text.py)

In Phase 4, plug in Whisper STT:

```python
import whisper

class SpeechToTextService:
    def __init__(self, model_name: str = "base"):
        self.model = whisper.load_model(model_name)
        self.is_development_mode = False

    def transcribe(self, audio_bytes: bytes, filename: str) -> Dict[str, Any]:
        # Transcribe audio file using Whisper
        result = self.model.transcribe(filename)
        return {
            "transcript": result["text"],
            "language": result.get("language", "en"),
            "confidence": 0.95,
            "is_development_mode": False
        }
```
