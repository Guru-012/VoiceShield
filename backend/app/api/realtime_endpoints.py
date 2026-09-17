import json
import base64
from typing import Dict, Any
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException, status
from fastapi.responses import JSONResponse

from app.schemas.realtime import RealtimeSessionCreateResponse, RealtimeDetectionResult
from app.services.realtime_session_manager import realtime_session_manager
from app.services.voice_detector import VoiceDetectionService
from app.services.speech_to_text import SpeechToTextService
from app.services.context_analyzer import ContextAnalyzer
from app.services.risk_engine import RiskEngine

realtime_router = APIRouter()

# Shared singleton instances
voice_detector = VoiceDetectionService()
stt_service = SpeechToTextService()
context_analyzer = ContextAnalyzer()
risk_engine = RiskEngine()

@realtime_router.post("/realtime/session", response_model=RealtimeSessionCreateResponse)
async def create_realtime_session():
    """
    Creates a new real-time voice detection session.
    """
    session_id = realtime_session_manager.create_session()
    return RealtimeSessionCreateResponse(
        session_id=session_id,
        sample_rate=16000,
        status="active",
        message="Real-time voice detection session initialized successfully."
    )

@realtime_router.delete("/realtime/session/{session_id}")
async def delete_realtime_session(session_id: str):
    """
    Terminates and cleans up an active real-time detection session.
    """
    session = realtime_session_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail=f"Real-time session '{session_id}' not found.")

    realtime_session_manager.cleanup_session(session_id)
    return {"status": "success", "session_id": session_id, "message": "Session terminated cleanly."}

@realtime_router.websocket("/ws/realtime/stream/{session_id}")
async def realtime_audio_stream_endpoint(websocket: WebSocket, session_id: str):
    """
    WebSocket endpoint for real-time live PCM audio streaming and AI voice detection.
    Accepts raw 16-bit 16kHz PCM audio bytes, buffers audio windows, runs Wav2Vec2 detector,
    and returns structured RealtimeDetectionResult payloads containing:
    - ai_probability
    - authenticity
    - confidence
    - risk_level
    - is_ai_generated
    """
    session = realtime_session_manager.get_session(session_id)
    if not session:
        await websocket.accept()
        await websocket.send_json({
            "type": "error",
            "message": f"Invalid or non-existent session ID '{session_id}'."
        })
        await websocket.close(code=4004)
        return

    await websocket.accept()
    await websocket.send_json({
        "type": "session_connected",
        "session_id": session_id,
        "message": "WebSocket real-time detection stream connected successfully."
    })

    try:
        while True:
            # Receive incoming message (binary PCM bytes or text JSON frame)
            message = await websocket.receive()

            chunk_bytes = b""
            if "bytes" in message and message["bytes"]:
                chunk_bytes = message["bytes"]
            elif "text" in message and message["text"]:
                try:
                    payload = json.loads(message["text"])
                    if payload.get("type") == "ping":
                        await websocket.send_json({"type": "pong"})
                        continue
                    elif payload.get("type") == "audio_chunk" and payload.get("base64_data"):
                        chunk_bytes = base64.b64decode(payload["base64_data"])
                except Exception:
                    continue

            if not chunk_bytes:
                continue

            # Process audio chunk through session buffer, pretrained AI model, STT, and Context Analyzer
            try:
                eval_result = realtime_session_manager.process_audio_chunk(
                    session_id=session_id,
                    audio_chunk_bytes=chunk_bytes,
                    voice_detector=voice_detector,
                    risk_engine=risk_engine,
                    stt_service=stt_service,
                    context_analyzer=context_analyzer
                )
            except ValueError as val_err:
                await websocket.send_json({
                    "type": "error",
                    "message": str(val_err)
                })
                break

            # If evaluation window was completed, return structured detection update
            if eval_result is not None:
                await websocket.send_json({
                    "type": "realtime_detection_update",
                    "data": eval_result
                })

    except WebSocketDisconnect:
        pass
    except Exception as exc:
        try:
            await websocket.send_json({
                "type": "error",
                "message": f"Stream processing error: {str(exc)}"
            })
        except Exception:
            pass
    finally:
        realtime_session_manager.cleanup_session(session_id)
