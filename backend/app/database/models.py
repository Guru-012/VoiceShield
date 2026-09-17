import json
from datetime import datetime
from sqlalchemy import Column, String, Float, Integer, Text, DateTime, Boolean
from app.database.database import Base

class AnalysisRecord(Base):
    __tablename__ = "analysis_records"

    id = Column(String, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
    filename = Column(String, nullable=False)
    voice_result = Column(String, nullable=False)
    ai_probability = Column(Float, nullable=False)
    voice_confidence = Column(Float, nullable=False)
    transcript = Column(Text, nullable=False)
    context_score = Column(Float, nullable=False)
    risk_score = Column(Integer, nullable=False)
    risk_level = Column(String, nullable=False)
    indicators_json = Column(Text, nullable=False, default="[]")
    recommendation = Column(Text, nullable=False)
    is_development_mode = Column(Boolean, default=True)

    def set_indicators(self, indicators_list):
        self.indicators_json = json.dumps(indicators_list)

    def get_indicators(self):
        try:
            return json.loads(self.indicators_json)
        except Exception:
            return []
