#!/bin/bash

echo "======================================"
echo "YouTube Subtitle + Chat Archiver"
echo "======================================"

mkdir -p subtitles
mkdir -p livechat
mkdir -p timeline
mkdir -p timeline_chunks

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


# ---------- TIMESTAMP ----------
def seconds_to_timestamp(sec):

    h = int(sec // 3600)
    m = int((sec % 3600) // 60)
    s = int(sec % 60)

    return f"{h:02}:{m:02}:{s:02}"


# ---------- SRT → TRANSCRIPT JSON ----------
def srt_to_holodex(video_id, srt_path, json_path):

    with open(srt_path,"r",encoding="utf-8") as f:
        content = f.read()

    blocks = re.split(r"\n\s*\n", content.strip())

    segments = []
    simplified = []
    last_text = ""

    for block in blocks:

        lines = block.split("\n")

        if len(lines) < 3:
            continue

        time_line = lines[1]
        text = " ".join(lines[2:]).strip()

        start,end = time_line.split(" --> ")

        def parse(t):
            h,m,s = t.replace(",",".").split(":")
            return int(h)*3600 + int(m)*60 + float(s)

        start = parse(start)
        end = parse(end)

        if last_text and text.startswith(last_text):
            continue

        if last_text and last_text.endswith(text):
            continue

        last_text = text

        segments.append({
            "start": start,
            "duration": round(end-start,3),
            "text": text
        })

        simplified.append(
            f"{seconds_to_timestamp(start)} {text}"
        )

    with open(json_path,"w",encoding="utf-8") as f:
        json.dump({
            "video_id":video_id,
            "segments":segments,
            "simplified":simplified
        },f,ensure_ascii=False)


# ---------- SIMPLIFY LIVE CHAT ----------
def simplify_livechat(input_file, output_file):

    messages = []

    with open(input_file,"r",encoding="utf-8") as f:

        for line in f:

            try:
                data = json.loads(line)
            except:
                continue

            action = data.get("replayChatItemAction")
            if not action:
                continue

            offset = float(action.get("videoOffsetTimeMsec","0"))/1000

            for a in action.get("actions",[]):

                item = a.get("addChatItemAction",{}).get("item",{})
                renderer = item.get("liveChatTextMessageRenderer")

                if not renderer:
                    continue

                author = renderer.get("authorName",{}).get("simpleText","")

                avatar = ""
                thumbs = renderer.get("authorPhoto",{}).get("thumbnails",[])
                if thumbs:
                    avatar = thumbs[-1]["url"]

                runs_data = renderer.get("message",{}).get("runs",[])

                message = ""

                for r in runs_data:

                    if "text" in r:
                        message += r["text"]

                    elif "emoji" in r:
                        message += r["emoji"].get("emojiId","")

                messages.append({
                    "time": offset,
                    "timestamp": seconds_to_timestamp(offset),
                    "author": author,
                    "avatar": avatar,
                    "message": message
                })

    with open(output_file,"w",encoding="utf-8") as f:
        json.dump(messages,f,ensure_ascii=False)


# ---------- BUILD TIMELINE ----------
def build_timeline(video_id):

    print("Building timelines for:", video_id)

    chat_file = f"livechat/{video_id}/chat_simple.json"

    chats = []

    if os.path.exists(chat_file):

        with open(chat_file,"r",encoding="utf-8") as f:
            chats = json.load(f)

        print("Loaded chat messages:", len(chats))

    else:
        print("No chat found")


    for lang in langs:

        sub_file = f"subtitles/{video_id}/{video_id}.{lang}.json"

        if not os.path.exists(sub_file):
            continue

        print("Building timeline:", lang)

        with open(sub_file,"r",encoding="utf-8") as f:
            subs = json.load(f)

        events = []

        for seg in subs["segments"]:
            events.append({
                "type":"subtitle",
                "time":seg["start"],
                "timestamp":seconds_to_timestamp(seg["start"]),
                "text":seg["text"]
            })

        for msg in chats:
            events.append({
                "type":"chat",
                "time":msg["time"],
                "timestamp":msg["timestamp"],
                "author":msg["author"],
                "avatar":msg["avatar"],
                "message":msg["message"]
            })

        events.sort(key=lambda x:x["time"])

        os.makedirs(f"timeline/{video_id}",exist_ok=True)

        out = f"timeline/{video_id}/timeline_{lang}.json"

        with open(out,"w",encoding="utf-8") as f:
            json.dump({
                "video_id":video_id,
                "lang":lang,
                "events":events
            },f,ensure_ascii=False)

        print("Events:",len(events))

        build_timeline_chunks(video_id,lang,events)


# ---------- BUILD CHUNKS ----------
def build_timeline_chunks(video_id,lang,events):

    print("Chunking timeline:", video_id, lang)

    chunk_dir = f"timeline_chunks/{video_id}/{lang}"

    os.makedirs(chunk_dir,exist_ok=True)

    chunks = {}

    for e in events:

        minute = int(e["time"]//60)

        if minute not in chunks:
            chunks[minute] = []

        chunks[minute].append(e)

    for minute in chunks:

        path = f"{chunk_dir}/chunk_{minute}.json"

        with open(path,"w",encoding="utf-8") as f:
            json.dump(chunks[minute],f,ensure_ascii=False)

    print("Chunks created:", len(chunks))


# ---------- MAIN LOOP ----------
for vid in streams:

    if processed >= limit:
        break

    print("Processing:", vid)

    sub_folder = f"subtitles/{vid}"
    chat_folder = f"livechat/{vid}"

    os.makedirs(sub_folder,exist_ok=True)
    os.makedirs(chat_folder,exist_ok=True)

    url = f"https://www.youtube.com/watch?v={vid}"

    raw = f"{chat_folder}/{vid}.live_chat.json"
    simp = f"{chat_folder}/{vid}.chat_simple.json"


    # ---------- SKIP IF SUBTITLES EXIST ----------
    if os.path.exists(f"{sub_folder}/{vid}.en.srt"):
        print("Subtitles already archived:", vid)

    else:

        subprocess.run([
            "yt-dlp",
            "--cookies","cookies.txt",
            "--js-runtimes","node",
            "--remote-components","ejs:github",
            "--write-subs",
            "--write-auto-subs",
            "--sub-langs","en,en-orig,ja,zh-Hans,zh-Hant",
            "--skip-download",
            "--no-overwrites",
            "-k",
            "--convert-subs","srt",
            "-o",f"{sub_folder}/%(id)s.%(ext)s",
            url
        ])


    # ---------- DOWNLOAD LIVECHAT ----------
    if not os.path.exists(raw):

        subprocess.run([
            "yt-dlp",
            "--cookies","cookies.txt",
            "--js-runtimes","node",
            "--remote-components","ejs:github",
            "--skip-download",
            "--write-subs",
            "--sub-langs","live_chat",
            "--sub-format","json",
            "--no-overwrites",
            "-o",f"{chat_folder}/%(id)s.live_chat.%(ext)s",
            url
        ])


    # ---------- BUILD TRANSCRIPTS ----------
    for lang in langs:

        srt = f"{sub_folder}/{vid}.{lang}.srt"
        js = f"{sub_folder}/{vid}.{lang}.json"

        if os.path.exists(srt):
            srt_to_holodex(vid,srt,js)


    # ---------- CHAT SIMPLIFY ----------
    if os.path.exists(raw) and not os.path.exists(simp):

        print("Simplifying chat:", vid)

        simplify_livechat(raw, simp)


    # ---------- BUILD TIMELINE ----------
    build_timeline(vid)

    processed += 1
    time.sleep(2)


print("Done")

EOF
