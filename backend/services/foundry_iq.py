import os
import httpx
from typing import Optional


def _cfg():
    """Read env vars at call time, not module load time."""
    return (
        os.getenv("AZURE_SEARCH_ENDPOINT", "").rstrip("/"),
        os.getenv("AZURE_SEARCH_KEY", ""),
        os.getenv("AZURE_SEARCH_INDEX", "studymindsearch"),
    )


async def ensure_index_exists() -> bool:
    """
    Create the Azure AI Search index if it doesn't exist.
    Called once at app startup.
    """
    endpoint, key, index = _cfg()
    if not endpoint or not key:
        print("[FoundryIQ] Not configured — skipping index creation")
        return False

    headers = {"Content-Type": "application/json", "api-key": key}
    check_url = f"{endpoint}/indexes/{index}?api-version=2023-11-01"

    # Check if index already exists
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            res = await client.get(check_url, headers=headers)
            if res.status_code == 200:
                print(f"[FoundryIQ] Index '{index}' already exists ")
                return True
    except Exception as e:
        print(f"[FoundryIQ] Could not check index: {e}")
        return False

    # Create index — use stable 2023-11-01 API with correct semantic schema
    schema = {
        "name": index,
        "fields": [
            {
                "name": "id",
                "type": "Edm.String",
                "key": True,
                "filterable": True,
                "retrievable": True,
                "searchable": False,
            },
            {
                "name": "content",
                "type": "Edm.String",
                "searchable": True,
                "retrievable": True,
                "filterable": False,
                "sortable": False,
                "facetable": False,
            },
            {
                "name": "title",
                "type": "Edm.String",
                "searchable": True,
                "retrievable": True,
                "filterable": True,
                "sortable": False,
                "facetable": False,
            },
            {
                "name": "metadata_source",
                "type": "Edm.String",
                "searchable": False,
                "retrievable": True,
                "filterable": True,
                "sortable": False,
                "facetable": False,
            },
        ],
        "semantic": {
            "configurations": [
                {
                    "name": "default",
                    "prioritizedFields": {
                        "titleField": {"fieldName": "title"},
                        "prioritizedContentFields": [{"fieldName": "content"}],
                        "prioritizedKeywordsFields": [{"fieldName": "metadata_source"}],
                    },
                }
            ]
        },
    }

    create_url = f"{endpoint}/indexes?api-version=2023-11-01"
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            res = await client.post(create_url, json=schema, headers=headers)
            if res.status_code in (200, 201):
                print(f"[FoundryIQ] Index '{index}' created successfully ")
                return True
            else:
                print(f"[FoundryIQ] Index creation failed: {res.status_code} {res.text}")
                return False
    except Exception as e:
        print(f"[FoundryIQ] Index creation error: {e}")
        return False


async def index_document(doc_id: str, content: str, title: str = "") -> bool:
    """
    Index a document into Azure AI Search so Foundry IQ can retrieve it.
    Chunks content into overlapping pieces for better retrieval.
    """
    endpoint, key, index = _cfg()
    if not endpoint or not key:
        return False

    url = f"{endpoint}/indexes/{index}/docs/index?api-version=2023-11-01"
    headers = {"Content-Type": "application/json", "api-key": key}

    # Overlapping chunks for better retrieval
    chunk_size = 1000
    overlap = 100
    chunks = []
    start = 0
    while start < len(content):
        chunks.append(content[start:start + chunk_size])
        start += chunk_size - overlap

    # Azure Search IDs: alphanumeric + dash/underscore only
    safe_id = "".join(c if c.isalnum() or c in "-_" else "_" for c in doc_id)

    documents = [
        {
            "@search.action": "mergeOrUpload",
            "id": f"{safe_id}-{idx}",
            "content": chunk,
            "title": title,
            "metadata_source": title or doc_id,
        }
        for idx, chunk in enumerate(chunks)
    ]

    try:
        async with httpx.AsyncClient(timeout=20) as client:
            res = await client.post(
                url,
                json={"value": documents},
                headers=headers,
            )
            res.raise_for_status()
        print(f"[FoundryIQ] Indexed {len(chunks)} chunks for '{title or doc_id}' ")
        return True
    except Exception as e:
        print(f"[FoundryIQ] Indexing failed: {e}")
        return False


async def search_grounded_context(query: str, top: int = 5) -> Optional[str]:
    """
    Query Azure AI Search (Foundry IQ) for grounded context.
    Returns formatted cited text, or None if unavailable.
    """
    endpoint, key, index = _cfg()
    if not endpoint or not key:
        return None

    url = f"{endpoint}/indexes/{index}/docs/search?api-version=2023-11-01"
    headers = {"Content-Type": "application/json", "api-key": key}

    payload = {
        "search": query,
        "top": top,
        "queryType": "semantic",
        "semanticConfiguration": "default",
        "captions": "extractive",
        "answers": "extractive|count-3",
        "select": "content,title,metadata_source",
    }

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            res = await client.post(url, json=payload, headers=headers)
            res.raise_for_status()
            data = res.json()

        results = data.get("value", [])
        if not results:
            return None

        cited_chunks = []
        for i, doc in enumerate(results):
            content = doc.get("content", "").strip()
            source = doc.get("metadata_source") or doc.get("title") or f"Source {i+1}"
            if content:
                cited_chunks.append(f"[{i+1}] ({source})\n{content[:800]}")

        return "\n\n".join(cited_chunks) if cited_chunks else None

    except Exception as e:
        print(f"[FoundryIQ] Search failed: {e}")
        return None