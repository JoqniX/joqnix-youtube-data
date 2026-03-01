#!/bin/bash

echo "======================================"
echo "YouTube Subtitle Archiver"
echo "======================================"

mkdir -p subtitles

python3 << 'EOF'
import json
import os
import subprocess
import time

with open("data/streams.json") as f:
    streams = json.load(f)

limit = 3
processed = 0

for vid in streams:

    if processed >= limit:
        break

    folder = f"subtitles/{vid}"

    if os.path.exists(folder):
        print("Skipping existing:", vid)
        continue

    print("Fetching subtitles for:", vid)

    os.makedirs(folder, exist_ok=True)

    url = f"https://www.youtube.com/watch?v={vid}"

    subprocess.run([
    "yt-dlp",
    "--cookies", "cookies.txt",
    "--skip-download",
    "--write-subs",
    "--write-auto-subs",
    "--sub-lang", "en,ja,ko,zh-Hans,zh-Hant",
    "--sub-format", "srt",
    "--convert-subs", "srt",
    "--no-playlist",
    "--ignore-errors",
    "-o", f"{folder}/%(id)s.%(ext)s",
    url
])

    processed += 1
    time.sleep(2)

print("Processed", processed, "videos")
EOF
