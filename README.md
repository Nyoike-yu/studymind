<<<<<<< HEAD
# 🎓 StudyMind — AI Study Agent

> Agents League Hackathon submission — Creative Apps track

An AI agent that ingests any learning material (PDF, URL, or topic), and autonomously runs a 4-step reasoning pipeline to help university students study smarter.

## 🤖 Agent Pipeline

| Step | Action | Description |
|------|--------|-------------|
| 1 | **Analyze** | Extracts key concepts & builds a study plan |
| 2 | **Summarize** | Writes a grounded, cited study summary |
| 3 | **Generate** | Creates flashcards + quiz questions |
| 4 | **Evaluate** | Scores quiz, identifies weak areas, gives adaptive feedback |

**Microsoft IQ used:** Foundry IQ (Azure AI Search) for grounded, cited knowledge retrieval

## 🚀 Setup

### Backend
```bash
cd backend
cp .env.example .env   # fill in your Azure keys
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

### Flutter App
```bash
cd studymind_app
flutter pub get
flutter run -d chrome   # web
```

### Azure Keys needed (.env)
- AZURE_OPENAI_API_KEY + AZURE_OPENAI_ENDPOINT (from Azure OpenAI resource)
- AZURE_SEARCH_ENDPOINT + AZURE_SEARCH_KEY (from Azure AI Search resource)
