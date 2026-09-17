import uuid
from typing import List
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, status
from sqlalchemy.orm import Session

from app.schemas.analysis import (
    AnalysisResponse,
    HealthResponse,
    HistoryListResponse,
    HistoryItem,
    AudioProcessResponse,
    AudioQualityMetadata
)
from app.services.audio_processor import AudioProcessor
from app.services.voice_detector import VoiceDetectionService
from app.services.speech_to_text import SpeechToTextService
from app.services.context_analyzer import ContextAnalyzer
from app.services.risk_engine import RiskEngine
from app.database.database import get_db
from app.database.models import AnalysisRecord

router = APIRouter()

# Initialize modular pipeline services
audio_processor = AudioProcessor()
voice_detector = VoiceDetectionService()
stt_service = SpeechToTextService()
context_analyzer = ContextAnalyzer()
risk_engine = RiskEngine()

@router.get("/health", response_model=HealthResponse)
async def health_check():
    """
    Backend Health Check Endpoint.
    """
    return HealthResponse(
        status="healthy",
        service="VoiceShield Core API",
        version="1.0.0-phase2",
        environment="development",
        is_development_mode=voice_detector.is_development_mode
    )

@router.post("/audio/process", response_model=AudioProcessResponse)
async def process_audio_endpoint(file: UploadFile = File(...)):
    """
    Dedicated Audio Preprocessing Endpoint.
    Receives raw audio, validates format/duration/quality, resamples to canonical 16 kHz Mono WAV,
    and returns processing metadata ready for AI detector ingestion.
    """
    if not file.filename:
        raise HTTPException(status_code=400, detail="No audio file provided.")

    contents = await file.read()

    try:
        canonical_wav, metadata = audio_processor.process_and_validate(contents, file.filename)
    except ValueError as val_err:
        raise HTTPException(status_code=400, detail=str(val_err))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Audio processing error: {str(exc)}")

    return AudioProcessResponse(
        status="success",
        filename=file.filename,
        audio_quality=AudioQualityMetadata(**metadata),
        message="Audio successfully processed, resampled to 16 kHz mono WAV, and validated for AI model input."
    )

@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_audio(
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Upload, preprocess, and analyze an audio file for AI voice impersonation and scam indicators.
    Executes full 16 kHz Mono WAV standardization and quality validation pipeline.
    """
    if not file.filename:
        raise HTTPException(status_code=400, detail="No audio file provided.")

    contents = await file.read()

    # 1. Preprocess, resample to 16kHz Mono WAV, and validate audio quality
    try:
        canonical_wav, audio_quality_dict = audio_processor.process_and_validate(contents, file.filename)
    except ValueError as val_err:
        raise HTTPException(status_code=400, detail=str(val_err))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Audio decoding or validation error: {str(exc)}")

    # 2. AI Voice Detection (Modular Pipeline receiving canonical 16kHz Mono WAV)
    voice_eval = voice_detector.predict(audio_quality_dict, canonical_wav)

    # 3. Speech-to-Text Transcription
    stt_eval = stt_service.transcribe(canonical_wav, file.filename)

    # 4. Context Analysis
    context_eval = context_analyzer.analyze(
        stt_eval["transcript"],
        is_development_mode=stt_service.is_development_mode
    )

    is_overall_dev_mode = voice_detector.is_development_mode or stt_service.is_development_mode

    # 5. Risk Engine Scoring
    risk_eval = risk_engine.calculate_risk(
        ai_probability=voice_eval.get("ai_probability", 0.0),
        context_score=context_eval.get("context_score", 0.0),
        indicators=context_eval.get("indicators", []),
        is_development_mode=is_overall_dev_mode
    )

    # Generate unique analysis ID
    analysis_id = f"vs_{uuid.uuid4().hex[:10]}"

    audio_quality_meta = AudioQualityMetadata(**audio_quality_dict)

    response = AnalysisResponse(
        analysis_id=analysis_id,
        filename=file.filename,
        voice_result=voice_eval.get("voice_result", "MODEL_NOT_CONNECTED"),
        display_title=voice_eval.get("display_title", "DEVELOPMENT MODE: AI Model Not Connected"),
        ai_probability=voice_eval.get("ai_probability"),
        voice_confidence=voice_eval.get("voice_confidence"),
        transcript=stt_eval["transcript"],
        context_score=context_eval.get("context_score"),
        risk_score=risk_eval["risk_score"],
        risk_level=risk_eval["risk_level"],
        indicators=context_eval["indicators"],
        recommendation=risk_eval["recommendation"],
        audio_quality=audio_quality_meta,
        is_development_mode=is_overall_dev_mode,
        demo_data_notice="" if not is_overall_dev_mode else voice_eval.get(
            "demo_data_notice",
            "DEMO DATA — NOT A REAL MODEL PREDICTION. These values are for interface testing only and must NOT be interpreted as a real voice-authenticity prediction."
        )
    )

    # Persist analysis in SQLite database
    try:
        record = AnalysisRecord(
            id=response.analysis_id,
            filename=response.filename,
            voice_result=response.voice_result,
            ai_probability=response.ai_probability or 0.0,
            voice_confidence=response.voice_confidence or 0.0,
            transcript=response.transcript,
            context_score=response.context_score or 0.0,
            risk_score=response.risk_score,
            risk_level=response.risk_level,
            recommendation=response.recommendation,
            is_development_mode=response.is_development_mode
        )
        record.set_indicators(response.indicators)
        db.add(record)
        db.commit()
    except Exception as e:
        db.rollback()
        print(f"Warning: Failed to persist analysis to DB: {e}")

    return response

@router.get("/history", response_model=HistoryListResponse)
async def get_history(db: Session = Depends(get_db)):
    """
    Retrieve list of past audio analysis results.
    """
    records = db.query(AnalysisRecord).order_by(AnalysisRecord.timestamp.desc()).all()
    items = [
        HistoryItem(
            id=r.id,
            timestamp=r.timestamp.isoformat(),
            filename=r.filename,
            voice_result=r.voice_result,
            risk_score=r.risk_score,
            risk_level=r.risk_level,
            ai_probability=r.ai_probability,
            is_development_mode=r.is_development_mode if hasattr(r, 'is_development_mode') else True
        )
        for r in records
    ]
    return HistoryListResponse(total=len(items), items=items)

@router.get("/analysis/{analysis_id}", response_model=AnalysisResponse)
async def get_analysis_detail(analysis_id: str, db: Session = Depends(get_db)):
    """
    Retrieve single analysis detail by ID.
    """
    record = db.query(AnalysisRecord).filter(AnalysisRecord.id == analysis_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Analysis record not found.")

    return AnalysisResponse(
        analysis_id=record.id,
        timestamp=record.timestamp.isoformat(),
        filename=record.filename,
        voice_result=record.voice_result,
        display_title="DEVELOPMENT MODE: AI Model Not Connected" if record.is_development_mode else record.voice_result,
        ai_probability=record.ai_probability,
        voice_confidence=record.voice_confidence,
        transcript=record.transcript,
        context_score=record.context_score,
        risk_score=record.risk_score,
        risk_level=record.risk_level,
        indicators=record.get_indicators(),
        recommendation=record.recommendation,
        is_development_mode=record.is_development_mode
    )

@router.delete("/history/{analysis_id}")
async def delete_history_item(analysis_id: str, db: Session = Depends(get_db)):
    """
    Delete analysis record from history.
    """
    record = db.query(AnalysisRecord).filter(AnalysisRecord.id == analysis_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Analysis record not found.")
    
    db.delete(record)
    db.commit()
    return {"status": "deleted", "id": analysis_id}
