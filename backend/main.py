from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from dotenv import load_dotenv
import os

load_dotenv()  # Must be before any other local imports

from routers import ingest, study, quiz
from services.foundry_iq import ensure_index_exists


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure Azure AI Search index exists
    await ensure_index_exists()
    yield
    # Shutdown: nothing to clean up

app = FastAPI(title="StudyMind API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(ingest.router, prefix="/api/ingest", tags=["ingest"])
app.include_router(study.router, prefix="/api/study", tags=["study"])
app.include_router(quiz.router, prefix="/api/quiz", tags=["quiz"])


@app.get("/health")
def health():
    return {"status": "ok", "service": "StudyMind API"}
