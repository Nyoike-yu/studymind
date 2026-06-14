from fastapi import APIRouter, HTTPException
from agents.study_agent import (
    get_session, step_analyze, step_summarize, step_generate
)

router = APIRouter()


def _session_or_404(session_id: str):
    session = get_session(session_id)
    if not session:
        raise HTTPException(404, "Session not found")
    return session


@router.post("/{session_id}/analyze")
async def analyze(session_id: str):
    _session_or_404(session_id)
    session = await step_analyze(session_id)
    return {
        "step": 1,
        "label": "Analyze",
        "study_plan": session.study_plan.model_dump() if session.study_plan else None,
        "topic": session.topic,
    }


@router.post("/{session_id}/summarize")
async def summarize(session_id: str):
    session = _session_or_404(session_id)
    if session.current_step < 1:
        raise HTTPException(400, "Run /analyze first")
    session = await step_summarize(session_id)
    return {"step": 2, "label": "Summarize", "summary": session.summary}


@router.post("/{session_id}/generate")
async def generate(session_id: str):
    session = _session_or_404(session_id)
    if session.current_step < 2:
        raise HTTPException(400, "Run /summarize first")
    session = await step_generate(session_id)
    return {
        "step": 3,
        "label": "Generate",
        "flashcards": [f.model_dump() for f in (session.flashcards or [])],
        "quiz": [
            {"question": q.question, "options": q.options}
            for q in (session.quiz or [])
            # NOTE: correct_index intentionally excluded — only sent at evaluation
        ],
    }


@router.get("/{session_id}")
def get_session_state(session_id: str):
    session = _session_or_404(session_id)
    return session
