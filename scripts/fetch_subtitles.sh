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
import re

langs = ["en","en-orig","ja","zh-Hans","zh-Hant"]

with open("data/streams.json") as f:
    streams = json.load(f)

limit = 10
processed = 0


# ---------- TIMESTAMP FORMAT ----------
def seconds_to_timestamp(sec):

    h = int(sec // 3600)
    m = int((sec % 3600) // 60)
    s = int(sec % 60)

    return f"{h:02}:{m:02}:{s:02}"


# ---------- SRT → HOLODEX TRANSCRIPT ----------
def srt_to_holodex(video_id, srt_path, json_path):

    with open(srt_path,"r",encoding="utf-8") as f:
        content=f.read()

    blocks=re.split(r"\n\s*\n",content.strip())

    segments=[]
    simplified=[]
    last_text=""

    for block in blocks:

        lines=block.split("\n")

        if len(lines)<3:
            continue

        time_line=lines[1]
        text=" ".join(lines[2:]).strip()

        start,end=time_line.split(" --> ")

        def parse(t):
            h,m,s=t.replace(",",".").split(":")
            return int(h)*3600 + int(m)*60 + float(s)

        start=parse(start)
        end=parse(end)

        # ----- DUPLICATE CLEANING -----

        if last_text and text.startswith(last_text):
            continue

        if last_text and last_text.endswith(text):
            continue

        last_text=text

        segments.append({
            "start":start,
            "duration":round(end-start,3),
            "text":text
        })

        simplified.append(
            f"{seconds_to_timestamp(start)} {text}"
        )

    data={
        "video_id":video_id,
        "segments":segments,
        "simplified":simplified
    }

    with open(json_path,"w",encoding="utf-8") as f:
        json.dump(data,f,ensure_ascii=False)


# ---------- MAIN LOOP ----------
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

    # ---------- SUBTITLES ----------
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

    # ---------- LIVE CHAT ----------
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

    # ---------- SRT → TRANSCRIPT JSON ----------
    for lang in langs:

        srt_file=f"{sub_folder}/{vid}.{lang}.srt"
        json_file=f"{sub_folder}/{vid}.{lang}.json"

        if os.path.exists(srt_file) and not os.path.exists(json_file):

            print("Creating transcript JSON:", vid, lang)

            srt_to_holodex(
                vid,
                srt_file,
                json_file
            )

    processed += 1
    time.sleep(2)


# ---------- BUILD TRANSCRIPT INDEX ----------
print("Building transcript index...")

index={}

for root,dirs,files in os.walk("subtitles"):

    for file in files:

        if file.endswith(".json"):

            parts=file.split(".")
            vid=parts[0]
            lang=parts[1]

            if vid not in index:
                index[vid]={}

            index[vid][lang]=os.path.join(root,file)

with open("livechat/transcript_index.json","w",encoding="utf-8") as f:

    json.dump(index,f,ensure_ascii=False,indent=2)

print("Done.")

EOF
