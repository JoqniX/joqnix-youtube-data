#!/bin/bash

echo "======================================"
echo "YouTube Subtitle Archiver"
echo "======================================"

mkdir -p subtitles

python3 << 'EOF'
import json
import os
import subprocess

# Load video IDs
with open("data/streams.json") as f:
    streams = json.load(f)

limit = 10
processed = 0

for vid in streams:

    if processed >= limit:
        break

    folder = f"subtitles/{vid}"

    # Skip videos already archived
    if os.path.exists(folder):
        print("Skipping existing:", vid)
        continue

    print("Fetching subtitles for:", vid)

    os.makedirs(folder, exist_ok=True)

    url = f"https://www.youtube.com/watch?v={vid}"

    subprocess.run([
        "yt-dlp",
        "--skip-download",
        "--write-auto-subs",
        "--sub-lang", "en,ja,ko,zh-Hans,zh-Hant",
        "--sub-format", "srt/best",
        "--convert-subs", "srt",
        "-o", f"{folder}/%(id)s.%(ext)s",
        url
    ])

    processed += 1

print("Processed", processed, "videos")
EOF
