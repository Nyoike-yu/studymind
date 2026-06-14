import requests
from bs4 import BeautifulSoup


def scrape_url(url: str) -> str:
    """
    Scrape readable text from a URL.
    Uses Jina Reader (r.jina.ai) for clean markdown extraction,
    falls back to BeautifulSoup.
    """
    # Try Jina Reader first — returns clean markdown from any URL
    try:
        jina_url = f"https://r.jina.ai/{url}"
        response = requests.get(jina_url, timeout=15, headers={
            "Accept": "text/plain"
        })
        if response.status_code == 200 and len(response.text) > 200:
            return response.text[:12000]  # cap to avoid token overflow
    except Exception:
        pass

    # Fallback: raw BeautifulSoup
    try:
        response = requests.get(url, timeout=10, headers={
            "User-Agent": "Mozilla/5.0 (compatible; StudyMindBot/1.0)"
        })
        soup = BeautifulSoup(response.text, "html.parser")

        # Remove scripts, styles, nav, footer
        for tag in soup(["script", "style", "nav", "footer", "header"]):
            tag.decompose()

        text = soup.get_text(separator="\n", strip=True)
        lines = [line for line in text.splitlines() if len(line.strip()) > 40]
        return "\n".join(lines)[:12000]
    except Exception as e:
        raise ValueError(f"Could not extract content from URL: {e}")
