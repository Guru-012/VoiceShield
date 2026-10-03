from typing import Dict, Any, Optional

from app.services.voip_session_manager import voip_manager


class VoIPAudioProcessor:
    """
    Processes audio received from a VoIP call.

    This service is separate from the existing Live Protection
    pipeline. It only handles audio belonging to VoIP calls.
    """

    def __init__(
        self,
        voice_detector: Any,
        risk_engine: Any,
    ):
        self.voice_detector = voice_detector
        self.risk_engine = risk_engine

    # ============================================================
    # START CALL
    # ============================================================

    def start_call(self, call_id: str):
        """
        Initialize a new VoIP analysis session.
        """

        voip_manager.init_call_session(call_id)

    # ============================================================
    # PROCESS AUDIO
    # ============================================================

    def process_audio(
        self,
        call_id: str,
        audio_chunk: bytes,
        sample_rate: int = 16000,
    ) -> Optional[Dict[str, Any]]:
        """
        Send an incoming PCM audio chunk to VoIPSessionManager.

        Expected audio:
            - PCM
            - 16-bit
            - mono
            - 16 kHz

        Returns an analysis result whenever the
        VoIPSessionManager has enough audio for analysis.
        """

        if not audio_chunk:
            return None

        result = voip_manager.process_audio_chunk(
            call_id=call_id,
            audio_chunk_bytes=audio_chunk,
            voice_detector=self.voice_detector,
            risk_engine=self.risk_engine,
            sample_rate=sample_rate,
        )

        return result

    # ============================================================
    # END CALL
    # ============================================================

    def end_call(self, call_id: str):
        """
        Clean up the VoIP analysis session.
        """

        voip_manager.cleanup_call_session(call_id)


# ================================================================
# GLOBAL PROCESSOR
# ================================================================

voip_audio_processor: Optional[VoIPAudioProcessor] = None


def initialize_voip_audio_processor(
    voice_detector: Any,
    risk_engine: Any,
):
    """
    Initialize the global VoIP audio processor.

    We pass the EXISTING voice detector and risk engine here.
    No new AI model is created.
    """

    global voip_audio_processor

    voip_audio_processor = VoIPAudioProcessor(
        voice_detector=voice_detector,
        risk_engine=risk_engine,
    )

    return voip_audio_processor