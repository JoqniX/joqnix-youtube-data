
# JoqniX YouTube Archive Data

This repository stores structured archive data for the **JoqniX YouTube channel**.

It automatically collects livestream metadata, playlists, subtitles, chat replay, transcripts, and timeline data using **yt-dlp** and GitHub Actions.

The generated data powers the **Livestream Archives viewer** on the JoqniX website:

https://joqnix.space/livestream-archives

---

# Overview

This repository acts as a **self-hosted data backend for JoqniX livestream archives**.

Instead of relying on third-party APIs or external archive services, this repository generates and stores structured data that can be directly consumed by the JoqniX website.

The system is conceptually similar to how **Holodex archives livestream data**, but is customized for the JoqniX channel.

---

# Automation Pipelines

This repository runs **three automated pipelines using GitHub Actions**.

## 1️⃣ Channel Stream Scanner

Fetches **all livestream video IDs from the JoqniX channel**.

Purpose:
- Maintain a complete list of streams
- Ensure new streams automatically enter the archive pipeline

Data stored in:

data/streams.json

Example:

```json
[
  "RX5QhGQpW94",
  "Q1fYownseYo",
  "3V5iJmjMdwU"
]

```
---

2️⃣ Playlist Mapping

Fetches all playlists on the JoqniX channel and maps which videos belong to each playlist.

This allows the website to display:

stream series

themed playlists

playlist navigation


Output:

data/playlist_map.json

Example structure:

```
{
  "playlist_id": {
    "title": "Gaming Streams",
    "videos": [
      "RX5QhGQpW94",
      "Q1fYownseYo"
    ]
  }
}
```

This data is also pushed to a Cloudflare Worker API used by the website backend.


---

3️⃣ Subtitle + Chat Archive Pipeline

The main archive pipeline.

For each stream listed in streams.json, the workflow:

1. Downloads subtitles using yt-dlp


2. Downloads livestream chat replay


3. Converts subtitles into structured transcript JSON


4. Simplifies chat replay data


5. Builds synchronized timelines


6. Splits timelines into minute chunks for fast loading




---

Repository Structure

```
data/
  streams.json
  playlist_map.json

subtitles/
  VIDEO_ID/
    VIDEO_ID.en.vtt
    VIDEO_ID.en.srt
    VIDEO_ID.en.json

livechat/
  VIDEO_ID/
    VIDEO_ID.live_chat.json
    VIDEO_ID.chat_simple.json

timeline/
  VIDEO_ID/
    timeline_en.json
    timeline_en-orig.json
    timeline_ja.json
    timeline_zh-Hans.json
    timeline_zh-Hant.json

timeline_chunks/
  VIDEO_ID/
    en/
      chunk_0.json
      chunk_1.json
    ja/
      chunk_0.json

scripts/
  fetch_subtitles.sh
```

---

Subtitle Data

Subtitles are downloaded using yt-dlp.

Supported languages:

en
en-orig
ja
zh-Hans
zh-Hant

Each subtitle track is stored in three formats:

.vtt  original YouTube format
.srt  converted subtitle format
.json structured transcript format

Example transcript JSON:

```
{
  "video_id": "RX5QhGQpW94",
  "segments": [
    {
      "start": 12.52,
      "duration": 3.14,
      "text": "Hello everyone"
    }
  ],
  "simplified": [
    "00:00:12 Hello everyone"
  ]
}
```

This format is inspired by the Holodex transcript structure.


---

Livestream Chat

Chat replay is downloaded using:

yt-dlp --sub-langs live_chat

Raw data:

VIDEO_ID.live_chat.json

Simplified data:

VIDEO_ID.chat_simple.json

Example simplified message:

```
{
  "time": 183.8,
  "timestamp": "00:03:03",
  "author": "@FrancoAlvarezflores",
  "avatar": "https://yt4.ggpht.com/.../s64...",
  "message": "Hi It's Me Franco 👋 🙂"
}
```

This simplified structure is optimized for rendering chat in the website UI.


---

Timeline System

The timeline merges subtitles and chat messages into a single chronological event list.

Example subtitle event:

```
{
  "type": "subtitle",
  "time": 412.5,
  "timestamp": "00:06:52",
  "text": "Let's start the game"
}
```
Example chat event:

```
{
  "type": "chat",
  "time": 414.2,
  "timestamp": "00:06:54",
  "author": "viewer123",
  "avatar": "avatar_url",
  "message": "Good luck!"
}
```

This allows subtitles and chat to be synchronized with the video playback timeline.


---

Timeline Chunking

Livestreams can contain thousands of timeline events.

To prevent slow loading, timelines are split into 1-minute chunks.

Example:

```
timeline_chunks/
  VIDEO_ID/
    en/
      chunk_0.json
      chunk_1.json
      chunk_2.json
```

The website loads chunks dynamically while the user scrolls through the timeline.


---

Website Integration

All generated data is consumed by the JoqniX website.

Livestream archive viewer:

https://joqnix.space/livestream-archives

The website uses this data for:

transcript viewing

chat replay

subtitle language switching

timeline navigation

timestamp scrubbing



---

Technology Used

Automation:

yt-dlp

Python

GitHub Actions


Website frontend:

Webstudio

JSON collections

custom UI components



---

Notes

This repository stores metadata and subtitles only.

It does not store any video content.

All video playback occurs through embedded YouTube players.


---

Future Improvements

Potential upgrades:

global transcript search

emoji rendering in chat

superchat detection

automatic chapter generation

highlight detection

AI clip discovery



---

Maintained by

JoqniX

Astral Progenitor of Constellations
VTuber / Creator / Streamer

Website
https://joqnix.space

Livestream Archives
https://joqnix.space/livestream-archives

---

