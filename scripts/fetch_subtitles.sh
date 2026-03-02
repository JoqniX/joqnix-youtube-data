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

        # ---- REMOVE DUPLICATE AUTO CAPTIONS ----
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


# ---------- SIMPLIFY LIVE CHAT ----------
def simplify_livechat(input_file, output_file):

    messages=[]

    with open(input_file,"r",encoding="utf-8") as f:

        for line in f:

            try:
                data=json.loads(line)
            except:
                continue

            action=data.get("replayChatItemAction")
            if not action:
                continue

            offset=float(action.get("videoOffsetTimeMsec","0"))/1000

            for a in action.get("actions",[]):

                item=a.get("addChatItemAction",{}).get("item",{})
                renderer=item.get("liveChatTextMessageRenderer")

                if not renderer:
                    continue

                author=renderer.get("authorName",{}).get("simpleText","")
                author_id=renderer.get("authorExternalChannelId","")

                avatar=""
                thumbs=renderer.get("authorPhoto",{}).get("thumbnails",[])
                if thumbs:
                    avatar=thumbs[-1]["url"]

                runs_data=renderer.get("message",{}).get("runs",[])

                message=""
                runs=[]

                for r in runs_data:

                    if "text" in r:

                        message+=r["text"]

                        runs.append({
                            "type":"text",
                            "text":r["text"]
                        })

                    elif "emoji" in r:

                        emoji=r["emoji"]
                        emoji_char=emoji.get("emojiId","")

                        img=""
                        thumbs=emoji.get("image",{}).get("thumbnails",[])
                        if thumbs:
                            img=thumbs[-1]["url"]

                        message+=emoji_char

                        runs.append({
                            "type":"emoji",
                            "text":emoji_char,
                            "url":img
                        })

                timestamp=seconds_to_timestamp(offset)

                messages.append({
                    "time":offset,
                    "timestamp":timestamp,
                    "author":author,
                    "author_id":author_id,
                    "avatar":avatar,
                    "message":message,
                    "runs":runs
                })

    with open(output_file,"w",encoding="utf-8") as f:
        json.dump(messages,f,ensure_ascii=False)


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

    # ---------- CHECK SUBTITLES ----------
    subtitles_complete = True

    for lang in langs:

        vtt = f"{sub_folder}/{vid}.{lang}.vtt"
        srt = f"{sub_folder}/{vid}.{lang}.srt"

        if not (os.path.exists(vtt) and os.path.exists(srt)):
            subtitles_complete = False
            break

    # ---------- CHECK CHAT ----------
    chat_file = f"{chat_folder}/{vid}.live_chat.json"
    chat_complete = os.path.exists(chat_file)

    if subtitles_complete and chat_complete:
        print("Skipping (already archived):", vid)
        continue

    print("Downloading:", vid)

    # ---------- DOWNLOAD SUBTITLES ----------
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

    # ---------- DOWNLOAD LIVECHAT ----------
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

    # ---------- CONVERT SUBTITLES ----------
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

    # ---------- SIMPLIFY CHAT ----------
    chat_raw=f"{chat_folder}/{vid}.live_chat.json"
    chat_simple=f"{chat_folder}/{vid}.chat_simple.json"

    if os.path.exists(chat_raw) and not os.path.exists(chat_simple):

        print("Simplifying chat:",vid)

        simplify_livechat(chat_raw,chat_simple)

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
