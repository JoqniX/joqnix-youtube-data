import os
import json
import requests
from pathlib import Path

SUBTITLE_DIR = "subtitles"
AI_DIR = "ai"

API_KEY = os.getenv("GROQ_API_KEY")

URL = "https://api.groq.com/openai/v1/chat/completions"

HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

MODEL = "llama3-70b-8192"


def compress_transcript(segments):
    """Reduce transcript size to avoid token limits"""
    lines = []

    for seg in segments[::5]:  # take every 5th subtitle
        start = int(seg.get("start", 0))
        text = seg.get("text", "")

        minutes = start // 60
        seconds = start % 60

        timestamp = f"{minutes:02}:{seconds:02}"
        lines.append(f"{timestamp} {text}")

    return "\n".join(lines)


def call_ai(prompt):

    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": "You analyze livestream transcripts."},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.3
    }

    r = requests.post(URL, headers=HEADERS, json=payload)
    r.raise_for_status()

    data = r.json()

    return data["choices"][0]["message"]["content"]


def process_video(video_id, transcript_file):

    ai_folder = Path(AI_DIR) / video_id
    ai_folder.mkdir(parents=True, exist_ok=True)

    summary_path = ai_folder / "summary.en.json"
    chapters_path = ai_folder / "chapters.en.json"

    if summary_path.exists():
        print(f"Skipping {video_id}, already processed")
        return

    with open(transcript_file, "r", encoding="utf-8") as f:
        transcript = json.load(f)

    compressed = compress_transcript(transcript)

    prompt = f"""
Analyze this livestream transcript.

Generate JSON with:

summary: short stream summary

chapters: list of chapters

Rules:
- chapters spaced 3-10 minutes
- titles short
- output JSON only

Transcript:
{compressed}
"""

    response = call_ai(prompt)

    try:
        result = json.loads(response)
    except:
        print("AI returned invalid JSON")
        print(response)
        return

    with open(summary_path, "w") as f:
        json.dump({
            "video_id": video_id,
            "summary": result.get("summary", "")
        }, f, indent=2)

    with open(chapters_path, "w") as f:
        json.dump({
            "video_id": video_id,
            "chapters": result.get("chapters", [])
        }, f, indent=2)

    print("Generated AI metadata for", video_id)


def main():

    for root, dirs, files in os.walk(SUBTITLE_DIR):

        for file in files:

            if file.endswith(".en.json"):

                video_id = file.split(".")[0]
                path = os.path.join(root, file)

                process_video(video_id, path)


if __name__ == "__main__":
    main()
