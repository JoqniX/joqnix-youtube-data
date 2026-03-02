#!/bin/bash

echo "======================================"
echo "YouTube Subtitle + Chat Archiver"
echo "======================================"

mkdir -p subtitles

python3 << 'EOF'
import json
import os
import subprocess
import time

with open("data/streams.json") as f:
    streams = json.load(f)

limit = 5
processed = 0

for vid in streams:

    if processed >= limit:
        break

    folder = f"subtitles/{vid}"
    url = f"https://www.youtube.com/watch?v={vid}"

    # Skip if files already exist
    if os.path.exists(folder) and len(os.listdir(folder)) > 0:
        print("Skipping existing:", vid)
        continue

    print("Processing:", vid)

    os.makedirs(folder, exist_ok=True)

    subprocess.run([
        "yt-dlp",
        "--cookies","cookies.txt",
        "--js-runtimes","node",
        "--remote-components","github",
        "--skip-download",
        "--write-subs",
        "--write-auto-subs",
        "--sub-langs","all,live_chat",
        "--convert-subs","srt",
        "--force-overwrites",
        "--ignore-errors",
        "--no-warnings",
        "-o",f"{folder}/%(id)s.%(ext)s",
        url
    ])

    processed += 1
    time.sleep(2)

print("Processed", processed, "videos")

EOF
