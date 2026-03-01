#!/bin/bash

echo "======================================"
echo "YouTube Subtitle + Chat Archiver"
echo "======================================"

mkdir -p subtitles
mkdir -p livechat

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

    sub_folder = f"subtitles/{vid}"
    chat_folder = f"livechat/{vid}"

    url = f"https://www.youtube.com/watch?v={vid}"

    print("Processing:", vid)

    os.makedirs(sub_folder, exist_ok=True)
    os.makedirs(chat_folder, exist_ok=True)

    # Download subtitles
    subprocess.run([
        "yt-dlp",
        "--cookies","cookies.txt",
        "--js-runtimes","node",
        "--skip-download",
        "--write-subs",
        "--write-auto-subs",
        "--sub-langs","all",
        "--convert-subs","srt",
        "--no-playlist",
        "--ignore-errors",
        "-o",f"{sub_folder}/%(id)s.%(ext)s",
        url
    ])

    # Download live chat replay
    subprocess.run([
        "yt-dlp",
        "--cookies","cookies.txt",
        "--js-runtimes","node",
        "--skip-download",
        "--write-subs",
        "--sub-langs","live_chat",
        "--no-playlist",
        "--ignore-errors",
        "-o",f"{chat_folder}/%(id)s.%(ext)s",
        url
    ])

    processed += 1
    time.sleep(2)

print("Processed", processed, "videos")

EOF
