#!/bin/bash

echo "======================================"
echo "Step 1: Fetch playlist IDs"
echo "======================================"

yt-dlp --flat-playlist -J "https://www.youtube.com/@joqnix/playlists" > channel_playlists.json

if [ ! -f channel_playlists.json ]; then
  echo "Failed to fetch playlists."
  exit 1
fi

python3 << EOF
import json

data=json.load(open("channel_playlists.json"))
ids=[p["id"] for p in data["entries"] if "id" in p]

open("playlist_ids.txt","w").write("\n".join(ids))
print("Playlist IDs extracted:",len(ids))
EOF


echo "======================================"
echo "Step 2: Fetch each playlist's videos"
echo "======================================"

rm -f all_playlists.json

while read playlist
do
  echo "Processing playlist $playlist"
  sleep 2

  yt-dlp --flat-playlist -J "https://www.youtube.com/playlist?list=$playlist" >> all_playlists.json

done < playlist_ids.txt


echo "======================================"
echo "Step 3: Build final playlist_map.json"
echo "======================================"

python3 << EOF
import json

playlists=[]

with open("all_playlists.json") as f:
    for line in f:
        playlists.append(json.loads(line))

result={}

for p in playlists:
    vids=[v["id"] for v in p.get("entries",[]) if "id" in v]

    result[p["id"]]={
        "title":p.get("title",""),
        "url":"https://www.youtube.com/playlist?list="+p["id"],
        "thumbnail":p.get("thumbnails",[{}])[-1].get("url",""),
        "videos":vids
    }

import os
os.makedirs("data",exist_ok=True)

with open("data/playlist_map.json","w") as f:
    json.dump(result,f)

print("playlist_map.json created")
EOF


rm channel_playlists.json
rm playlist_ids.txt
rm all_playlists.json

echo "Playlist map generation complete"
