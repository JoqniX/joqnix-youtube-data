#!/bin/bash

echo "Fetching livestream video IDs..."

yt-dlp \
--flat-playlist \
--print "%(id)s" \
--match-filter "live_status=was_live" \
"https://www.youtube.com/@joqnix/streams" \
| python3 -c 'import sys,json; print(json.dumps([x.strip() for x in sys.stdin if x.strip()]))' \
> data/streams.json

echo "Saved livestream IDs to data/streams.json"
