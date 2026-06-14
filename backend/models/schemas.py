from pydantic import BaseModel
from typing import Optional, List
from enum import Enum


class InputType(str, Enum):
    PDF = "pdf"
    TOPIC = "topic"
    URL = "url"


class IngestRequest(BaseModel):
    input_type: InputType
    content: str  # topic text or URL; PDF sent as multipart


class StudyPlan(BaseModel):
    topic: str
    milestones: List[str]
    key_concepts: List[str]
    estimated_hours: int


class Flashcard(BaseModel):
    front: str
    back: str


class QuizQuestion(BaseModel):
    question: str
    options: List[str]
    correct_index: int
    explanation: str


class StudySession(BaseModel):
    session_id: str
    topic: str
    raw_content: str
    study_plan: Optional[StudyPlan] = None
    flashcards: Optional[List[Flashcard]] = None
    quiz: Optional[List[QuizQuestion]] = None
    summary: Optional[str] = None
    weak_areas: Optional[List[str]] = None
    current_step: int = 0  # tracks agent progress 0-5


class QuizSubmission(BaseModel):
    session_id: str
    answers: List[int]  # user's chosen option indices


class QuizResult(BaseModel):
    score: int
    total: int
    percentage: float
    weak_areas: List[str]
    feedback: str
