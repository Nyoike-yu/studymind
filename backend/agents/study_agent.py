import os
import re
import json
import uuid
import asyncio
from openai import OpenAI
from models.schemas import (
    StudySession, StudyPlan, Flashcard, QuizQuestion
)
from services.foundry_iq import search_grounded_context, index_document

# GitHub Models uses the standard OpenAI SDK pointed at Microsoft's inference endpoint
_client: OpenAI | None = None

def _get_client() -> OpenAI:
    global _client
    if _client is None:
        _client = OpenAI(
            api_key=os.getenv("GITHUB_TOKEN"),
            base_url="https://models.inference.ai.azure.com",
        )
    return _client

# In-memory session store
sessions: dict[str, StudySession] = {}


def _chat_sync(system: str, user: str) -> str:
    """Synchronous LLM call — always run via asyncio.to_thread."""
    response = _get_client().chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        temperature=0.3,
        max_tokens=2000,
    )
    return response.choices[0].message.content.strip()


async def _chat(system: str, user: str) -> str:
    """Non-blocking LLM call."""
    return await asyncio.to_thread(_chat_sync, system, user)


async def _chat_json(system: str, user: str) -> dict | list:
    """Call the model and parse JSON response."""
    raw = await _chat(
        system + "\n\nRespond ONLY with valid JSON. No markdown fences, no explanation.",
        user
    )
    raw = raw.strip()
    raw = re.sub(r"^```(?:json)?\s*\n?", "", raw, flags=re.IGNORECASE)
    raw = re.sub(r"\n?```\s*$", "", raw)
    return json.loads(raw.strip())


# ── STEP 1: Analyze ──────────────────────────────────────────────────────────

async def step_analyze(session_id: str) -> StudySession:
    session = sessions[session_id]

    # Index content into Foundry IQ FIRST so subsequent steps can retrieve it
    await index_document(session_id, session.raw_content, session.topic)

    # Search for grounded context from Azure AI Search
    grounded = await search_grounded_context(session.topic)
    context = f"\n\nGrounded context from knowledge base:\n{grounded}" if grounded else ""

    result = await _chat_json(
        system="You are an expert academic tutor. Extract key concepts and build a structured study plan.",
        user=f"""Analyze this content and return a JSON study plan.

Content:
{session.raw_content[:6000]}{context}

Return this exact JSON shape:
{{
  "topic": "concise topic name",
  "key_concepts": ["concept1", "concept2", ...],
  "milestones": ["milestone1", "milestone2", ...],
  "estimated_hours": 2
}}

Rules:
- key_concepts: 6-10 items
- milestones: 4-5 items
- estimated_hours: integer only
- No comments in JSON"""
    )

    session.study_plan = StudyPlan(**result)
    session.topic = result["topic"]
    session.current_step = 1
    sessions[session_id] = session
    return session


# ── STEP 2: Summarize ────────────────────────────────────────────────────────

async def step_summarize(session_id: str) -> StudySession:
    session = sessions[session_id]

    grounded = await search_grounded_context(f"summary of {session.topic}")
    context = f"\n\nGrounded context from knowledge base:\n{grounded}" if grounded else ""

    summary = await _chat(
        system="You are an expert academic tutor. Write clear, engaging summaries for university students.",
        user=f"""Write a comprehensive study summary for: {session.topic}

Content:
{session.raw_content[:6000]}{context}

Format the summary with:
- A 2-3 sentence overview
- Key points as short paragraphs (not bullet points)
- A closing "What to remember" paragraph

Keep it under 400 words."""
    )

    session.summary = summary
    session.current_step = 2
    sessions[session_id] = session
    return session


# ── STEP 3: Generate Flashcards + Quiz ───────────────────────────────────────

async def step_generate(session_id: str) -> StudySession:
    session = sessions[session_id]
    concepts = session.study_plan.key_concepts if session.study_plan else []

    # Flashcards
    fc_result = await _chat_json(
        system="You are a university tutor creating study flashcards.",
        user=f"""Create 8 flashcards for: {session.topic}
Key concepts: {', '.join(concepts)}

Return a JSON array with exactly this shape:
[{{"front": "question or term", "back": "answer or definition"}}]

No extra keys. 8 items exactly."""
    )
    session.flashcards = [Flashcard(**fc) for fc in fc_result]

    # Quiz
    quiz_result = await _chat_json(
        system="You are a university professor writing multiple-choice exam questions.",
        user=f"""Create 5 multiple-choice quiz questions for: {session.topic}
Key concepts: {', '.join(concepts)}

Return a JSON array with exactly this shape:
[{{
  "question": "...",
  "options": ["A) ...", "B) ...", "C) ...", "D) ..."],
  "correct_index": 0,
  "explanation": "why this answer is correct"
}}]

Rules:
- correct_index is 0-3 (integer, not a letter)
- All 4 options must be present
- 5 questions exactly"""
    )
    session.quiz = [QuizQuestion(**q) for q in quiz_result]

    session.current_step = 3
    sessions[session_id] = session
    return session


# ── STEP 4: Evaluate + Adapt ─────────────────────────────────────────────────

async def step_evaluate(session_id: str, answers: list[int]) -> tuple[StudySession, dict]:
    session = sessions[session_id]
    quiz = session.quiz or []

    if not quiz:
        return session, {"score": 0, "total": 0, "percentage": 0.0,
                         "weak_areas": [], "wrong_questions": [],
                         "feedback": "No quiz questions were available."}

    correct = 0
    wrong_questions = []

    for q, user_ans in zip(quiz, answers):
        if user_ans == q.correct_index:
            correct += 1
        else:
            wrong_questions.append({
                "question": q.question,
                "your_answer": q.options[user_ans] if 0 <= user_ans < len(q.options) else "N/A",
                "correct_answer": q.options[q.correct_index],
                "explanation": q.explanation,
            })

    score_pct = (correct / len(quiz)) * 100
    weak_areas = [wq["question"][:60] for wq in wrong_questions]

    if wrong_questions:
        feedback = await _chat(
            system="You are a supportive academic tutor giving personalised feedback.",
            user=f"""Student scored {correct}/{len(quiz)} ({score_pct:.0f}%) on {session.topic}.

Wrong questions:
{json.dumps(wrong_questions, indent=2)}

Write 3-4 sentences of encouraging, specific feedback.
Tell them exactly what concepts to review and how."""
        )
    else:
        feedback = f"Outstanding! You scored {correct}/{len(quiz)} — a perfect score on {session.topic}. Keep up the excellent work!"

    session.weak_areas = weak_areas
    session.current_step = 4
    sessions[session_id] = session

    return session, {
        "score": correct,
        "total": len(quiz),
        "percentage": round(score_pct, 1),
        "weak_areas": weak_areas,
        "wrong_questions": wrong_questions,
        "feedback": feedback,
    }


def create_session(topic: str, raw_content: str) -> str:
    session_id = str(uuid.uuid4())
    sessions[session_id] = StudySession(
        session_id=session_id,
        topic=topic,
        raw_content=raw_content,
    )
    return session_id


def get_session(session_id: str) -> StudySession | None:
    return sessions.get(session_id)
