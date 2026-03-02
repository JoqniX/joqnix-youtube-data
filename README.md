

# JoqniX YouTube Archive Data

This repository stores structured archive data for the **JoqniX YouTube channel**.

It automatically collects subtitles, live chat, transcripts, and timeline data from streams using **yt-dlp** and processes them into formats that can power custom archive tools.

The data in this repository is used by the **Livestream Archives page** on the JoqniX website:

https://joqnix.space/livestream-archives


---

# Purpose

The goal of this repository is to create a **self-hosted archive system** similar to Holodex.

Instead of relying on external APIs, this repository stores structured data that can be directly consumed by the JoqniX website.

Features enabled by this system include:

• Subtitle browsing  
• Transcript display  
• Clickable timestamps  
• Replayable livestream chat  
• Timeline navigation  
• Fast chunked loading for large streams  


---

# Automation

Data is collected automatically using **GitHub Actions**.

The workflow periodically:

1. Reads a list of stream video IDs from:

data/streams.json

2. Downloads subtitles and live chat using **yt-dlp**

3. Converts subtitles into structured JSON transcript format

4. Simplifies YouTube chat data

5. Builds a timeline combining chat + subtitles

6. Splits timelines into minute chunks for fast loading

7. Commits generated data back into the repository


---

# Repository Structure

data/ streams.json

subtitles/ VIDEO_ID/ VIDEO_ID.en.vtt VIDEO_ID.en.srt VIDEO_ID.en.json

livechat/ VIDEO_ID/ VIDEO_ID.live_chat.json VIDEO_ID.chat_simple.json

timeline/ VIDEO_ID/ timeline_en.json timeline_ja.json

timeline_chunks/ VIDEO_ID/ en/ chunk_0.json chunk_1.json chunk_2.json

scripts/ fetch_subtitles.sh

---

# Data Formats

## Subtitles

Subtitles are downloaded from YouTube using **yt-dlp**.

Languages currently supported:

en en-orig ja zh-Hans zh-Hant

Each subtitle track is stored as:

.vtt  (original format) .srt  (converted format) .json (structured transcript)

Example transcript JSON:

```json
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

The JSON format is inspired by the Holodex transcript structure.


---

Live Chat

YouTube livestream chat replay is downloaded using:

yt-dlp --sub-langs live\_chat

The raw chat file is stored as:

VIDEO\_ID.live\_chat.json

This file contains the full YouTube replay structure.

It is then simplified into:

VIDEO\_ID.chat\_simple.json

Example simplified chat message:

{
  "time": 183.8,
  "timestamp": "00:03:03",
  "author": "@FrancoAlvarezflores",
  "avatar": "https://yt4.ggpht.com/.../s64...",
  "message": "Hi It's Me Franco 👋 🙂"
}

This simplified format is designed for easy rendering on the website.


---

Timeline System

A timeline system merges subtitles and chat messages into a single chronological event list.

Example event:

{
  "type": "subtitle",
  "time": 412.5,
  "timestamp": "00:06:52",
  "text": "Let's start the game"
}

or

{
  "type": "chat",
  "time": 414.2,
  "timestamp": "00:06:54",
  "author": "viewer123",
  "avatar": "avatar_url",
  "message": "Good luck!"
}


---

Timeline Files

Each subtitle language gets its own timeline:

timeline/VIDEO\_ID/timeline\_en.json
timeline/VIDEO\_ID/timeline\_ja.json

This allows the website to switch subtitle languages dynamically.


---

Timeline Chunking

Streams can contain thousands of events, which would be slow to load all at once.

To solve this, timelines are split into 1-minute chunks.

timeline\_chunks/
VIDEO\_ID/
en/
chunk\_0.json
chunk\_1.json
chunk\_2.json

This allows the website to load timeline data on demand while the user scrolls.


---

Website Integration

The archive data is consumed by the JoqniX website.

Livestream archive page:

https://joqnix.space/livestream-archives

The website uses these files to power features such as:

• transcript viewing
• chat replay
• timestamp navigation
• subtitle search
• timeline scrubbing


---

Technology Used

Automation and data extraction relies on:

• yt-dlp
• Python
• GitHub Actions

The website frontend uses:

• Webstudio
• static JSON collections
• custom UI components


---

Notes

This repository only stores structured metadata and subtitles.

It does not store video content.

All video playback still occurs through YouTube embeds.


---

Future Improvements

Possible improvements include:

• transcript search across all streams
• chat emoji rendering
• superchat detection
• stream chapter generation
• AI generated highlights


---

Maintained by

JoqniX

Astral Progenitor of Constellations
VTuber / Creator / Streamer

https://joqnix.space

---