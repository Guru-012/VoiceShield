from typing import Dict, Any, List

class RiskEngine:
    """
    Risk Assessment Engine for VoiceShield.
    Combines voice authenticity deepfake probability and speech context risk score
    to compute an overall threat score (0-100) and risk level (LOW/MEDIUM/HIGH/DEV_MODE).
    """

    def calculate_risk(
        self,
        ai_probability: float,
        context_score: float,
        indicators: List[str],
        is_development_mode: bool = True
    ) -> Dict[str, Any]:
        """
        Calculates final composite risk score and risk level classification.
        Evaluates AI voice deepfake score and suspicious scam context as independent threat signals.
        """
        if is_development_mode:
            return {
                "risk_score": 0,
                "risk_level": "DEV_MODE",
                "recommendation": "DEVELOPMENT MODE: AI voice detection model and Speech-to-Text engine are pending plugin. Connect models for production predictions."
            }

        voice_risk = int(round(ai_probability * 100))
        context_risk = int(round(context_score * 100))

        # Composite risk takes maximum of the individual risk signals
        # EITHER a synthetic voice OR a severe scam script triggers elevated threat status!
        composite_score = max(voice_risk, context_risk)

        # Synergy booster: if BOTH AI voice deepfake AND scam context are present (>= 35), boost risk (+15 pts)
        if voice_risk >= 35 and context_risk >= 35:
            composite_score = min(100, composite_score + 15)

        indicators_text = " ".join([str(ind).lower() for ind in indicators])

        # Security overrides:
        # 1. OTP/credential harvesting is a critical security threat (minimum score 60 -> MEDIUM/HIGH)
        if "otp" in indicators_text or "credential" in indicators_text:
            composite_score = max(composite_score, 60)

        # 2. OTP + Financial demand or Urgency together -> HIGH threat (minimum score 85 -> HIGH)
        if ("otp" in indicators_text or "credential" in indicators_text) and (
            "financial" in indicators_text or "urgency" in indicators_text or "impersonation" in indicators_text
        ):
            composite_score = max(composite_score, 85)

        # 3. Financial request + Urgency / Impersonation -> HIGH threat (minimum score 75 -> HIGH)
        if "financial" in indicators_text and (
            "urgency" in indicators_text or "impersonation" in indicators_text or "secrecy" in indicators_text
        ):
            composite_score = max(composite_score, 75)

        risk_score = max(0, min(100, composite_score))

        if risk_score <= 30:
            risk_level = "LOW"
            recommendation = "No suspicious voice cloning or scam manipulation pattern detected. Standard vigilance advised."
        elif risk_score <= 65:
            risk_level = "MEDIUM"
            recommendation = "Potential voice anomaly or suspicious intent detected. Exercise caution and verify caller identity through an official separate channel."
        else:
            risk_level = "HIGH"
            recommendation = "High risk of voice cloning or impersonation scam! Do not share OTPs, passwords, or initiate financial transactions."

        return {
            "risk_score": risk_score,
            "risk_level": risk_level,
            "recommendation": recommendation
        }
