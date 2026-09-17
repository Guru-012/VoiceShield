import json
from typing import Dict, Any
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.services.voip_manager import voip_manager
from app.services.voice_detector import VoiceDetectionService
from app.services.risk_engine import RiskEngine

voip_router = APIRouter()

# Singletons shared across WebSockets
voice_detector = VoiceDetectionService()
risk_engine = RiskEngine()

# ----------------------------------------------------------------------------
# 1. WEBRTC SIGNALING WEBSOCKET ROUTE
# ----------------------------------------------------------------------------
@voip_router.websocket("/ws/voip/signal/{client_id}")
async def voip_signaling_endpoint(websocket: WebSocket, client_id: str):
    """
    WebSocket endpoint for WebRTC signaling exchange (offer, answer, ice_candidate, hangup).
    """
    await voip_manager.connect_client(client_id, websocket)
    try:
        while True:
            data_str = await websocket.receive_text()
            try:
                msg = json.loads(data_str)
            except Exception:
                continue

            msg_type = msg.get("type")
            target_id = msg.get("target_id")
            room_id = msg.get("room_id")

            if msg_type == "join_room" and room_id:
                if room_id not in voip_manager.active_rooms:
                    voip_manager.active_rooms[room_id] = []
                if client_id not in voip_manager.active_rooms[room_id]:
                    voip_manager.active_rooms[room_id].append(client_id)

                # Send room join confirmation
                await websocket.send_json({
                    "type": "room_joined",
                    "room_id": room_id,
                    "client_id": client_id,
                    "peer_clients": [c for c in voip_manager.active_rooms[room_id] if c != client_id]
                })

            elif msg_type in ["offer", "answer", "ice_candidate", "hangup"] and target_id:
                # Forward WebRTC signaling payload to target peer client
                msg["sender_id"] = client_id
                await voip_manager.send_signaling_message(target_id, msg)

    except WebSocketDisconnect:
        voip_manager.disconnect_client(client_id)

# ----------------------------------------------------------------------------
# 2. REAL-TIME LIVE AUDIO STREAMING & AI THREAT EVALUATION ROUTE
# ----------------------------------------------------------------------------
@voip_router.websocket("/ws/voip/stream/{call_id}/{client_id}")
async def voip_audio_stream_endpoint(websocket: WebSocket, call_id: str, client_id: str):
    """
    WebSocket endpoint for receiving live PCM audio chunks, running AI voice deepfake detection,
    and pushing rolling EMA threat probability updates.
    """
    await websocket.accept()
    voip_manager.init_call_session(call_id)

    try:
        while True:
            # Receive binary PCM audio bytes
            chunk_bytes = await websocket.receive_bytes()
            if not chunk_bytes:
                continue

            # Process chunk through voip_manager ring buffer and pretrained AI model
            eval_result = voip_manager.process_audio_chunk(
                call_id=call_id,
                audio_chunk_bytes=chunk_bytes,
                voice_detector=voice_detector,
                risk_engine=risk_engine
            )

            # If evaluation window was reached, return threat alert JSON to client
            if eval_result is not None:
                await websocket.send_json({
                    "type": "ai_threat_update",
                    "data": eval_result
                })

    except (WebSocketDisconnect, Exception):
        pass
    finally:
        voip_manager.cleanup_call_session(call_id)
