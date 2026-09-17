import io
import os
from typing import Dict, Any, Optional
import numpy as np
import scipy.io.wavfile as wavfile

try:
    import torch
    from transformers import pipeline
    HAS_TRANSFORMERS = True
except ImportError:
    HAS_TRANSFORMERS = False

class VoiceDetectionService:
    """
    Voice Detection Service for VoiceShield.
    Integrates real AI audio deepfake & voice spoofing detection model.
    Default model: 'garystafford/wav2vec2-deepfake-voice-detector' (Hugging Face Hub).
    """

    DEFAULT_MODEL_NAME = "garystafford/wav2vec2-deepfake-voice-detector"

    def __init__(self, model_name_or_path: Optional[str] = None):
        self.model_name = model_name_or_path or self.DEFAULT_MODEL_NAME
        self.classifier = None
        self.is_development_mode = True
        self.model_load_error: Optional[str] = None

        self._load_model()

    def _load_model(self):
        if not HAS_TRANSFORMERS:
            self.model_load_error = "PyTorch or Transformers libraries are not installed."
            self.is_development_mode = True
            return

        try:
            # Initialize Hugging Face audio-classification pipeline on CPU
            self.classifier = pipeline(
                "audio-classification",
                model=self.model_name,
                device=-1
            )
            self.is_development_mode = False
            self.model_load_error = None
            print(f"Successfully loaded real AI Voice Detection model: '{self.model_name}'")
        except Exception as e:
            self.is_development_mode = True
            self.model_load_error = f"Model load deferred for '{self.model_name}': {str(e)}"
            print(f"Notice: {self.model_load_error}. Operating in Development Mode fallback.")

    def predict(self, audio_metadata: Dict[str, Any], canonical_wav_bytes: bytes) -> Dict[str, Any]:
        """
        Runs AI voice deepfake detection on canonical 16kHz mono WAV bytes.
        Passes in-memory float audio array directly to avoid ffmpeg binary requirement.
        """
        if self.is_development_mode or self.classifier is None:
            return {
                "voice_result": "MODEL_NOT_CONNECTED",
                "display_title": "DEVELOPMENT MODE: AI Model Not Connected",
                "ai_probability": 0.0,
                "voice_confidence": 0.0,
                "is_development_mode": True,
                "demo_data_notice": "DEMO DATA — NOT A REAL MODEL PREDICTION. These values are for interface testing only and must NOT be interpreted as a real voice-authenticity prediction.",
                "detector_note": self.model_load_error or "AI voice detection model not connected yet."
            }

        try:
            # Decode 16kHz Mono WAV bytes directly in-memory to float32 numpy array
            sr, int_data = wavfile.read(io.BytesIO(canonical_wav_bytes))
            if int_data.dtype == np.int16:
                float_audio = int_data.astype(np.float32) / 32768.0
            elif int_data.dtype == np.int32:
                float_audio = int_data.astype(np.float32) / 2147483648.0
            else:
                float_audio = int_data.astype(np.float32)

            # Pass in-memory audio dictionary directly to Hugging Face classifier
            results = self.classifier({"raw": float_audio, "sampling_rate": sr})
            print(f"RAW Wav2Vec2 RESULTS: {results}")
            # Example Hugging Face pipeline output:
            # [{'label': 'fake', 'score': 0.94}, {'label': 'real', 'score': 0.06}]

            ai_score = 0.0
            real_score = 0.0

            for res in results:
                label = str(res.get("label", "")).lower()
                score = float(res.get("score", 0.0))

                if any(kw in label for kw in ["fake", "spoof", "synthetic", "cloned", "ai", "deepfake"]):
                    ai_score = score
                elif any(kw in label for kw in ["real", "bonafide", "human", "authentic", "original"]):
                    real_score = score

            if ai_score == 0.0 and real_score == 0.0 and len(results) > 0:
                top = results[0]
                label = str(top.get("label", "")).lower()
                score = float(top.get("score", 0.0))
                if any(kw in label for kw in ["fake", "1"]):
                    ai_score = score
                    real_score = 1.0 - score
                else:
                    real_score = score
                    ai_score = 1.0 - score
            elif ai_score > 0.0 and real_score == 0.0:
                real_score = max(0.0, 1.0 - ai_score)
            elif real_score > 0.0 and ai_score == 0.0:
                ai_score = max(0.0, 1.0 - real_score)

            ai_probability = round(ai_score, 4)
            voice_confidence = round(max(ai_score, real_score), 4)

            if ai_probability >= 0.65:
                voice_result = "AI_VOICE_DETECTED"
                display_title = "🚨 WARNING: AI-Generated / Cloned Voice Detected"
            elif ai_probability >= 0.35:
                voice_result = "POSSIBLY_AI_GENERATED"
                display_title = "⚠️ CAUTION: Voice Anomaly Detected"
            else:
                voice_result = "REAL_VOICE"
                display_title = "✅ REAL HUMAN VOICE DETECTED"

            return {
                "voice_result": voice_result,
                "display_title": display_title,
                "ai_probability": ai_probability,
                "voice_confidence": voice_confidence,
                "is_development_mode": False,
                "demo_data_notice": "",
                "model_name": self.model_name,
                "detector_note": f"Real AI Model Inference Active ('{self.model_name}')"
            }
        except Exception as exc:
            print(f"Error during model inference: {exc}")
            return {
                "voice_result": "INFERENCE_ERROR",
                "display_title": "MODEL INFERENCE ERROR",
                "ai_probability": 0.0,
                "voice_confidence": 0.0,
                "is_development_mode": True,
                "detector_note": f"Inference error: {str(exc)}"
            }


