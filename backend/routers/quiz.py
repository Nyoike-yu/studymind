from fastapi import APIRouter, HTTPException
from agents.study_agent import get_session, step_evaluate
from models.schemas import QuizSubmission

router = APIRouter()


@router.post("/submit")
async def submit_quiz(submission: QuizSubmission):
    session = get_session(submission.session_id)
    if not session:
        raise HTTPException(404, "Session not found")
    if session.current_step < 3:
        raise HTTPException(400, "Generate study materials first")
    if not session.quiz:
        raise HTTPException(400, "No quiz available")

    _, result = await step_evaluate(submission.session_id, submission.answers)
    return result
