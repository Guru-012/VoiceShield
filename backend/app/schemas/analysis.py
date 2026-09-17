from datetime import datetime, timezone
from typing import List, Optional
from pydantic import BaseModel, Field

class AudioQualityMetadata(BaseModel):
    duration_seconds: float = Field(..., description="Duration of processed audio in seconds")
    original_sample_rate: int = Field(..., description="Original input audio sample rate in Hz")
    processed_sample_rate: int = Field(16000, description="Canonical output sample rate (16,000 Hz)")
    original_channels: int = Field(..., description="Original input audio channels")
    processed_channels: int = Field(1, description="Canonical output channels (1 = Mono)")
    format: str = Field("wav", description="Canonical output audio format")
    processing_status: str = Field("READY_FOR_MODEL", description="Pipeline readiness status")

class AudioProcessResponse(BaseModel):
    status: str = Field("success", description="Processing status")
    filename: str = Field(..., description="Input filename")
    audio_quality: AudioQualityMetadata = Field(..., description="Processed audio metadata")
    message: str = Field("Audio successfully processed, resampled to 16 kHz mono WAV, and validated for AI model input.", description="Human readable message")

class AnalysisResponse(BaseModel):
    analysis_id: str = Field(..., description="Unique ID for the analysis session")
    timestamp: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    filename: str = Field(..., description="Name of the analyzed audio file")
    voice_result: str = Field(..., description="MODEL_NOT_CONNECTED (in dev mode) or REAL_VOICE / POSSIBLY_AI_GENERATED")
    display_title: str = Field(default="DEVELOPMENT MODE: AI Model Not Connected", description="User-facing main result heading")
    ai_probability: Optional[float] = Field(None, ge=0.0, le=1.0, description="Probability of voice being AI generated (0.0 - 1.0)")
    voice_confidence: Optional[float] = Field(None, ge=0.0, le=1.0, description="Confidence level of detection model")
    transcript: str = Field(..., description="Speech-to-text transcript or dev mode placeholder notice")
    context_score: Optional[float] = Field(None, ge=0.0, le=1.0, description="Suspicious context risk score")
    risk_score: int = Field(0, ge=0, le=100, description="Overall computed risk score (0-100)")
    risk_level: str = Field("DEV_MODE", description="LOW, MEDIUM, HIGH, or DEV_MODE")
    indicators: List[str] = Field(default_factory=list, description="Suspicious context indicators detected")
    recommendation: str = Field(..., description="Safety action advice for the user")
    audio_quality: Optional[AudioQualityMetadata] = Field(None, description="Technical audio quality metadata")
    is_development_mode: bool = Field(default=True, description="Flag indicating development placeholder vs real AI model")
    demo_data_notice: str = Field(
        default="DEMO DATA — NOT A REAL MODEL PREDICTION. These values are for interface testing only and must NOT be interpreted as a real voice-authenticity prediction.",
        description="Explicit notice regarding dev mode UI testing data"
    )
    disclaimer: str = Field(
        default="DEVELOPMENT MODE: AI voice detection model and Speech-to-Text engine are pending plugin. AI voice detection is probabilistic.",
        description="Legal and technical disclaimer"
    )

class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    environment: str
    is_development_mode: bool
    timestamp: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

class HistoryItem(BaseModel):
    id: str
    timestamp: str
    filename: str
    voice_result: str
    risk_score: int
    risk_level: str
    ai_probability: Optional[float]
    is_development_mode: bool = True

class HistoryListResponse(BaseModel):
    total: int
    items: List[HistoryItem]
