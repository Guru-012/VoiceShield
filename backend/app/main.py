import os
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.endpoints import router as api_router
from app.api.voip_endpoints import voip_router
from app.api.realtime_endpoints import realtime_router
from app.database.database import engine, Base

# Create DB tables if they don't exist yet
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="VoiceShield API",
    description="AI-Powered Real-Time Detection and Prevention of Voice Cloning Impersonation Attacks (SIH 2026 PS 26104)",
    version="1.0.0-phase3",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Enable CORS for Flutter mobile/web development clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global Exception Handler (Never expose raw tracebacks to user)
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    print(f"Unhandled Exception: {exc}")
    return JSONResponse(
        status_code=500,
        content={
            "detail": "An internal server error occurred while processing your audio request. Please try again."
        }
    )

app.include_router(api_router, prefix="/api")
app.include_router(voip_router, prefix="/api")
app.include_router(realtime_router, prefix="/api")

@app.get("/")
async def root():
    return {
        "project": "VoiceShield",
        "tagline": "AI Voice Cloning Impersonation Detection System",
        "version": "1.0.0-phase1",
        "health_check": "/api/health",
        "docs": "/docs"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
