from datetime import datetime, timezone
from typing import Optional
from pydantic import BaseModel, Field

class RealtimeSessionCreateResponse(BaseModel):
    session_id: str = Field(..., description="Unique real-time detection session ID")
    created_at: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    sample_rate: int = Field(16000, description="Target sample rate in Hz (16,000 Hz canonical)")
    status: str = Field("active", description="Session status")
    message: str = Field("Real-time detection session initialized successfully.", description="Session status message")

class RealtimeDetectionResult(BaseModel):
    session_id: str = Field(..., description="Unique session ID for the live stream")
    chunk_index: int = Field(0, description="Sequential index of evaluated audio window")
    ai_probability: float = Field(..., ge=0.0, le=1.0, description="Probability of voice being AI generated (0.0 - 1.0)")
    authenticity: float = Field(..., ge=0.0, le=1.0, description="Authenticity score of voice (1.0 - ai_probability)")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence rating of model detection")
    risk_level: str = Field("DEV_MODE", description="LOW, MEDIUM, HIGH, or DEV_MODE")
    is_ai_generated: bool = Field(False, description="True if ai_probability >= 0.5")
    raw_ai_probability: float = Field(..., ge=0.0, le=1.0, description="Instantaneous window AI probability")
    rolling_ai_probability: float = Field(..., ge=0.0, le=1.0, description="Exponential moving average AI probability")
    threat_alert_triggered: bool = Field(False, description="True if rolling AI threat threshold breached")
    voice_result: str = Field(..., description="Classification category label")
    display_title: str = Field(..., description="User-facing threat alert title")
    transcript: Optional[str] = Field("", description="Live Speech-to-text transcript output")
    context_score: Optional[float] = Field(0.0, description="Context scam threat score")
    indicators: Optional[list] = Field(default_factory=list, description="Scam context and voice indicators")
    timestamp: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    is_development_mode: bool = Field(True, description="Flag indicating dev mode vs active model inference")
