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

langs = ["en","en-orig","ja","zh-Hans","zh-Hant"]

with open("data/streams.json") as f:
    streams = json.load(f)

limit = 50
processed = 0

for vid in streams:

    if processed >= limit:
        break

    sub_folder = f"subtitles/{vid}"
    chat_folder = f"livechat/{vid}"

    url = f"https://www.youtube.com/watch?v={vid}"

    os.makedirs(sub_folder, exist_ok=True)
    os.makedirs(chat_folder, exist_ok=True)

    print("Checking:", vid)

    # ---- CHECK SUBTITLES ----
    subtitles_complete = True

    for lang in langs:
        vtt = f"{sub_folder}/{vid}.{lang}.vtt"
        srt = f"{sub_folder}/{vid}.{lang}.srt"

        if not (os.path.exists(vtt) and os.path.exists(srt)):
            subtitles_complete = False
            break

    # ---- CHECK LIVECHAT ----
    chat_file = f"{chat_folder}/{vid}.live_chat.json"
    chat_complete = os.path.exists(chat_file)

    if subtitles_complete and chat_complete:
        print("Skipping (already archived):", vid)
        continue

    print("Downloading:", vid)

    # SUBTITLES
    subprocess.run([
        "yt-dlp",
        "--cookies","cookies.txt",
        "--js-runtimes","node",
        "--remote-components","github",

        "--write-subs",
        "--write-auto-subs",

        "--sub-langs","en,en-orig,ja,zh-Hans,zh-Hant",

        "--skip-download",
        "--ignore-no-formats-error",
        "--no-overwrites",

        "-k",
        "--convert-subs","srt",

        "--ignore-errors",
        "--no-warnings",

        "-o",f"{sub_folder}/%(id)s.%(ext)s",
        url
    ])

    # LIVE CHAT
    subprocess.run([
        "yt-dlp",
        "--cookies","cookies.txt",
        "--js-runtimes","node",
        "--remote-components","github",

        "--skip-download",
        "--write-subs",
        "--sub-langs","live_chat",
        "--sub-format","json",

        "--ignore-no-formats-error",
        "--no-overwrites",

        "--ignore-errors",
        "--no-warnings",

        "-o",f"{chat_folder}/%(id)s.live_chat.%(ext)s",
        url
    ])

    processed += 1
    time.sleep(2)

print("Processed", processed, "videos")

EOF
