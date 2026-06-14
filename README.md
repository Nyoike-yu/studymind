StudyMind - AI Study Agent

Agents League Hackathon submission: Creative Apps track

An AI agent that ingests any learning material (PDF, URL, or topic), and autonomously runs a 4-step reasoning pipeline to help university students study smarter.

Agent Pipeline
Analyze: Extracts key concepts & builds a study plan 
Summarize: Writes a grounded, cited study summary
Generate: Creates flashcards + quiz questions
Evaluate: Scores quiz, identifies weak areas, gives adaptive feedback 

Microsoft IQ used: Foundry IQ (Azure AI Search) for grounded, cited knowledge retrieval

Setup
backend

cd backend
cp .env.example .env   # fill in your Azure keys
pip install -r requirements.txt
uvicorn main:app --reload --port 8000


Flutter App

cd studymind_app
flutter pub get
flutter run -d chrome   # web


Keys needed in .env

GITHUB_TOKEN: from github.com/marketplace/models: GPT-4o: Create Personal Access Token (needs models:read permission)
AZURE_SEARCH_ENDPOINT: from Azure AI Search resource -> Overview -> URL
AZURE_SEARCH_KEY: from Azure AI Search resource -> Keys -> Primary admin key
AZURE_SEARCH_INDEX: the name of your Azure AI Search resource (e.g studymindsearch)
