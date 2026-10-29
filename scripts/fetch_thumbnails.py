import json
import hashlib
import base64
import subprocess
import requests
from datetime import datetime, timedelta, timezone
from pathlib import Path

STREAMS_FILE = "data/streams.json"
ALL_STREAMS_FILE = "data/all_streams.json"

THUMBNAIL_DIR = Path("thumbnails")
MAX_SIZE = 10 * 1024 * 1024  # 10MB


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()


def extract_video_ids_from_streams(streams_data):
    video_ids = []

    if isinstance(streams_data, list):
        for item in streams_data:
            if isinstance(item, str):
                video_ids.append(item)
            elif isinstance(item, dict) and "video_id" in item:
                video_ids.append(item["video_id"])
    elif isinstance(streams_data, dict):
        video_ids.extend(streams_data.keys())

    return video_ids


def extract_video_ids_from_all_streams(all_streams_data):
    if not isinstance(all_streams_data, dict):
        return []
    # The key can exist with a null value, so don't rely on the .get default.
    return all_streams_data.get("all_status_stream_ids") or []


SCHEDULE_API = "https://api.joqnix.space/schedules/streams"
ACTIVE_FLAGS = {"SCHEDULED", "AWAITING", "DELAYED", "POSTPONED", "LIVE"}


def fetch_active_stream_ids():
    """Ids of streams that are upcoming or live, from the schedules API."""
    today = datetime.now(timezone.utc).date()
    params = {
        "from": (today - timedelta(days=1)).isoformat(),
        "to": (today + timedelta(days=30)).isoformat(),
    }

    try:
        response = requests.get(SCHEDULE_API, params=params, timeout=20)
        response.raise_for_status()
        streams = response.json().get("streams", [])
    except Exception as error:
        print(f"Could not load the schedule, nothing will be refreshed: {error}")
        return set()

    return {
        item["videoId"]
        for item in streams
        if item.get("statusFlag") in ACTIVE_FLAGS and item.get("videoId")
    }


def download_thumbnail(video_id, output_dir):
    url = f"https://www.youtube.com/watch?v={video_id}"

    cmd = [
        "yt-dlp",
        "--cookies", "cookies.txt",
        "--js-runtimes", "node",
        "--remote-components", "ejs:github",
        "--skip-download",
        "--write-thumbnail",
        "--convert-thumbnails", "jpg",
        "-o", str(output_dir / "%(id)s"),
        url
    ]

    print(f"Running yt-dlp for {video_id}")
    process = subprocess.Popen(cmd)
    process.wait()

    # If yt-dlp succeeded normally
    if process.returncode == 0:
        for file in output_dir.glob(f"{video_id}.jpg"):
            return file

    print(f"yt-dlp failed for {video_id}. Trying fallback...")

    # 🔥 Fallback for scheduled streams
    fallback_urls = [
        f"https://i.ytimg.com/vi/{video_id}/maxresdefault.jpg",
        f"https://i.ytimg.com/vi/{video_id}/sddefault.jpg",
        f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg",
    ]

    for thumb_url in fallback_urls:
        try:
            response = requests.get(thumb_url, timeout=10)
            if response.status_code == 200:
                jpg_path = output_dir / f"{video_id}.jpg"
                with open(jpg_path, "wb") as f:
                    f.write(response.content)
                print(f"Downloaded thumbnail via fallback for {video_id}")
                return jpg_path
        except Exception:
            continue

    print(f"Fallback failed for {video_id}")
    return None


def encode_base64(image_path):
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def main():
    all_video_ids = set()

    # 🔹 Load all_streams.json (PRIMARY SOURCE)
    all_streams_path = Path(ALL_STREAMS_FILE)
    if all_streams_path.exists():
        with open(all_streams_path, "r", encoding="utf-8") as f:
            all_streams_data = json.load(f)

        ids = extract_video_ids_from_all_streams(all_streams_data)
        print(f"Loaded {len(ids)} IDs from all_streams.json")
        all_video_ids.update(ids)
    else:
        print("all_streams.json not found.")

    # 🔹 Load streams.json (SECONDARY SOURCE)
    streams_path = Path(STREAMS_FILE)
    if streams_path.exists():
        with open(streams_path, "r", encoding="utf-8") as f:
            streams_data = json.load(f)

        ids = extract_video_ids_from_streams(streams_data)
        print(f"Loaded {len(ids)} IDs from streams.json")
        all_video_ids.update(ids)
    else:
        print("streams.json not found.")

    if not all_video_ids:
        print("No video IDs found.")
        return

    # Thumbnails can be changed after scheduling or mid-stream, so streams
    # that have not ended are re-downloaded every run; the hash check below
    # skips unchanged ones.
    active_ids = fetch_active_stream_ids()
    print(f"{len(active_ids)} upcoming / live streams will be refreshed")

    THUMBNAIL_DIR.mkdir(exist_ok=True)

    for video_id in sorted(all_video_ids):
        print(f"\nProcessing {video_id}")

        video_dir = THUMBNAIL_DIR / video_id
        video_dir.mkdir(exist_ok=True)

        jpg_path = video_dir / "thumbnail.jpg"
        hash_path = video_dir / "hash.txt"
        base64_path = video_dir / "thumbnail_base64.json"

        # 🚀 SPEED UPGRADE: finished streams are only fetched once
        if (
            video_id not in active_ids
            and jpg_path.exists()
            and hash_path.exists()
            and base64_path.exists()
        ):
            print(f"{video_id} already processed. Skipping.")
            continue

        temp_file = download_thumbnail(video_id, video_dir)

        if not temp_file:
            continue

        if temp_file.name != "thumbnail.jpg":
            temp_file.rename(jpg_path)
        else:
            jpg_path = temp_file

        if jpg_path.stat().st_size > MAX_SIZE:
            print(f"Thumbnail too large for {video_id}")
            jpg_path.unlink(missing_ok=True)
            continue

        new_hash = sha256_file(jpg_path)

        # If unchanged, skip base64 regeneration
        if hash_path.exists():
            old_hash = hash_path.read_text().strip()
            if old_hash == new_hash and base64_path.exists():
                print("Thumbnail unchanged. Skipping base64.")
                continue

        hash_path.write_text(new_hash)

        encoded = encode_base64(jpg_path)

        with open(base64_path, "w", encoding="utf-8") as f:
            json.dump({
                "video_id": video_id,
                "mime_type": "image/jpeg",
                "base64": encoded
            }, f)

        print(f"Updated thumbnail for {video_id}")


if __name__ == "__main__":
    main()
