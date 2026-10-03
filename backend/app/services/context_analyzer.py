import re
from typing import Dict, Any, List

class ContextAnalyzer:
    """
    Context Analyzer Module for VoiceShield.
    Analyzes real transcripts from Whisper STT for psychological manipulation techniques,
    financial demands, credential harvesting, urgency tactics, authority impersonation, and secrecy requests.
    """

    KEYWORD_PATTERNS = {
        "financial_request": [
            r"transfer", r"send money", r"rupees", r"dollars", r"account", r"bank",
            r"pay immediately", r"payment", r"up[i1]", r"gpay", r"phonepe", r"cash",
            r"wire transfer", r"credit card", r"deposit",r"link"
        ],
        "otp_request": [
            r"otp", r"one time password", r"verification code", r"pin", r"password", r"cvv", r"security code"
        ],
        "urgency_detected": [
            r"immediately", r"urgently", r"right now", r"without delay", r"emergency", r"hurry", r"asap", r"fast"
        ],
        "impersonation_detected": [
            r"bank manager", r"officer", r"police", r"crime branch", r"government",
            r"law enforcement", r"cbi", r"customs", r"manager", r"boss", r"agent", r"support",r"press the link","link"
        ],
        "secrecy_coercion": [
            r"don'?t tell", r"do not tell", r"keep this confidential", r"do not hang up", r"secret", r"inform no one", r"keep silent"
        ]
    }

    INDICATOR_LABELS = {
        "financial_request": "Urgent financial transfer request detected",
        "otp_request": "Attempt to harvest OTP / security credentials",
        "urgency_detected": "High-pressure urgency tactics employed",
        "impersonation_detected": "Impersonation of authority figure / financial institution",
        "secrecy_coercion": "Coercion to maintain secrecy / do not verify"
    }

    SCORE_WEIGHTS = {
        "otp_request": 50,
        "financial_request": 40,
        "impersonation_detected": 30,
        "secrecy_coercion": 25,
        "urgency_detected": 20
    }

    def analyze(self, transcript: str, is_development_mode: bool = True) -> Dict[str, Any]:
        """
        Analyzes the transcript text for suspicious scam indicators.
        """
        if is_development_mode or "Speech-to-text model not connected" in transcript:
            return {
                "flags": {},
                "context_score": 0.0,
                "indicators": ["DEVELOPMENT MODE: Speech-to-text context analysis pending STT plugin"]
            }

        if not transcript or transcript.strip() in ["No audible speech recognized.", ""]:
            return {
                "flags": {},
                "context_score": 0.0,
                "indicators": ["No suspicious context indicators detected."]
            }

        transcript_lower = transcript.lower()
        flags: Dict[str, bool] = {}
        detected_indicators: List[str] = []
        score_weight = 0

        for key, patterns in self.KEYWORD_PATTERNS.items():
            matched = any(re.search(pattern, transcript_lower) for pattern in patterns)
            flags[key] = matched
            if matched:
                detected_indicators.append(self.INDICATOR_LABELS[key])
                score_weight += self.SCORE_WEIGHTS.get(key, 20)

        context_score = min(1.0, score_weight / 100.0)
        if not detected_indicators:
            detected_indicators = ["No suspicious context indicators detected."]

        return {
            "flags": flags,
            "context_score": round(context_score, 2),
            "indicators": detected_indicators
        }
