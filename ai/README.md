# VoiceShield AI Engine

Directory structure for AI/ML deepfake voice detection models, datasets, training scripts, and evaluation benchmarks.

---

## Directory Structure

```
ai/
├── models/         # Binary model weights (PyTorch .pth, ONNX)
├── datasets/       # ASVspoof 2019/2021, WaveFake audio samples
├── training/       # PyTorch model training & feature extraction scripts
├── evaluation/     # EER (Equal Error Rate) & ROC curve scripts
└── README.md       # AI technical guidelines
```

Refer to [docs/model.md](file:///C:/Users/tejas/.gemini/antigravity/scratch/VoiceShield/docs/model.md) for step-by-step instructions on plugging trained model binaries into `VoiceDetectionService`.
