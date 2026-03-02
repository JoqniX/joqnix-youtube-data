import os
import json
import requests
from pathlib import Path

SUBTITLE_DIR = "subtitles"
AI_DIR = "ai"

GITHUB_REPO = "JoqniX/joqnix-youtube-data"
GITHUB_BRANCH = "Main-dayo"

API_KEY = os.getenv("GROQ_API_KEY")

URL = "https://api.groq.com/openai/v1/chat/completions"

HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

MODEL = "llama-3.3-70b-versatile"


def compress_transcript(data):

    if isinstance(data, dict) and "segments" in data:
        segments = data["segments"]
    else:
        segments = data

    lines = []

    for seg in segments[::5]:

        start = int(seg.get("start", 0))
        text = seg.get("text", "").replace("\n", " ").strip()

        minutes = start // 60
        seconds = start % 60

        timestamp = f"{minutes:02}:{seconds:02}"

        lines.append(f"{timestamp} {text}")

    return "\n".join(lines)


def fetch_transcript_local(video_id):

    path = Path(SUBTITLE_DIR) / video_id / f"{video_id}.en.json"

    if path.exists():

        print(f"Loading transcript locally for {video_id}")

        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)

    return None


def fetch_transcript_github(video_id):

    url = f"https://raw.githubusercontent.com/{GITHUB_REPO}/{GITHUB_BRANCH}/subtitles/{video_id}/{video_id}.en.json"

    try:

        print(f"Fetching transcript from GitHub for {video_id}")

        r = requests.get(url)
        r.raise_for_status()

        return r.json()

    except Exception as e:

        print(f"Failed to fetch transcript from GitHub: {e}")
        return None


def get_transcript(video_id):

    transcript = fetch_transcript_local(video_id)

    if transcript:
        return transcript

    return fetch_transcript_github(video_id)


def call_ai(prompt):

    payload = {
        "model": MODEL,
        "messages": [
            {
                "role": "system",
                "content": "You analyze livestream transcripts and return JSON only."
            },
            {
                "role": "user",
                "content": prompt
            }
        ],
        "temperature": 0.3,
        "max_tokens": 1000
    }

    r = requests.post(URL, headers=HEADERS, json=payload)

    if r.status_code != 200:
        print("Groq API Error:")
        print(r.text)
        r.raise_for_status()

    data = r.json()

    return data["choices"][0]["message"]["content"]


def process_video(video_id):

    ai_folder = Path(AI_DIR) / video_id
    ai_folder.mkdir(parents=True, exist_ok=True)

    summary_path = ai_folder / "summary.en.json"
    chapters_path = ai_folder / "chapters.en.json"

    if summary_path.exists():
        print(f"Skipping {video_id}, already processed")
        return

    transcript = get_transcript(video_id)

    if not transcript:
        print(f"No transcript found for {video_id}")
        return

    compressed = compress_transcript(transcript)

    compressed = compressed[:12000]

    prompt = f"""
Analyze this livestream transcript.

Return JSON only in this format:

{{
 "summary": "short stream summary",
 "chapters": [
   {{"time": "MM:SS", "title": "chapter title"}}
 ]
}}

Rules:
- chapters every 3–10 minutes
- titles short
- no explanations
- JSON only

Transcript:
{compressed}
"""

    try:

        response = call_ai(prompt)

        result = json.loads(response)

    except Exception as e:

        print("AI parsing failed:")
        print(e)
        print("AI response:")
        print(response if 'response' in locals() else "None")
        return

    with open(summary_path, "w", encoding="utf-8") as f:

        json.dump({
            "video_id": video_id,
            "summary": result.get("summary", "")
        }, f, indent=2)

    with open(chapters_path, "w", encoding="utf-8") as f:

        json.dump({
            "video_id": video_id,
            "chapters": result.get("chapters", [])
        }, f, indent=2)

    print(f"Generated AI metadata for {video_id}")


def main():

    for root, dirs, files in os.walk(SUBTITLE_DIR):

        for file in files:

            if file.endswith(".en.json"):

                video_id = file.split(".")[0]

                process_video(video_id)


if __name__ == "__main__":
    main()
