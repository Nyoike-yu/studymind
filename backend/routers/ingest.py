from fastapi import APIRouter, UploadFile, File, HTTPException, Form
from agents.study_agent import create_session
from services.pdf_parser import extract_text_from_pdf
from services.url_scraper import scrape_url
from urllib.parse import urlparse

router = APIRouter()


@router.post("/pdf")
async def ingest_pdf(file: UploadFile = File(...)):
    if not (file.filename or "").lower().endswith(".pdf"):
        raise HTTPException(400, "Only PDF files are supported")
    file_bytes = await file.read()
    try:
        text = extract_text_from_pdf(file_bytes)
    except Exception as e:
        raise HTTPException(500, f"PDF parsing failed: {e}")
    if len(text.strip()) < 100:
        raise HTTPException(400, "Could not extract enough text from this PDF")
    topic = (file.filename or "document").replace(".pdf", "").replace("_", " ").replace("-", " ")
    session_id = create_session(topic=topic, raw_content=text)
    return {"session_id": session_id, "char_count": len(text)}

@router.post("/url")
async def ingest_url(url: str = Form(...)):
    url = url.strip()
    if not url.startswith(("http://", "https://")):
        raise HTTPException(400, "Please enter a valid URL starting with http:// or https://")
    try:
        text = scrape_url(url)
    except Exception as e:
        raise HTTPException(500, f"Could not fetch URL: {e}")
    if len(text.strip()) < 100:
        raise HTTPException(400, "Could not extract enough content from that URL")
    # Extract a human-readable topic from the URL path
    parsed = urlparse(url)
    path_parts = [p for p in parsed.path.split("/") if p]
    topic = path_parts[-1].replace("-", " ").replace("_", " ") if path_parts else parsed.netloc
    session_id = create_session(topic=topic, raw_content=text)
    return {"session_id": session_id, "char_count": len(text)}


@router.post("/topic")
async def ingest_topic(topic: str = Form(...)):
    topic = topic.strip()
    if len(topic) < 3:
        raise HTTPException(400, "Topic must be at least 3 characters")
    session_id = create_session(topic=topic, raw_content=topic)
    return {"session_id": session_id}
