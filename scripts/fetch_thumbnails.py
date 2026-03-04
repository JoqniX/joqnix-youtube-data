import json
import hashlib
import base64
import subprocess
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
    return all_streams_data.get("all_status_stream_ids", [])


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

    # 🚀 STREAM LOGS LIVE
    process = subprocess.Popen(cmd)
    process.wait()

    if process.returncode != 0:
        print(f"yt-dlp failed for {video_id}")
        return None

    for file in output_dir.glob(f"{video_id}.jpg"):
        return file

    return None


def encode_base64(image_path):
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def main():
    all_video_ids = set()

    # 🔹 Load all_streams.json FIRST (primary source)
    all_streams_path = Path(ALL_STREAMS_FILE)
    if all_streams_path.exists():
        with open(all_streams_path, "r", encoding="utf-8") as f:
            all_streams_data = json.load(f)

        ids = extract_video_ids_from_all_streams(all_streams_data)
        print(f"Loaded {len(ids)} IDs from all_streams.json")
        all_video_ids.update(ids)
    else:
        print("all_streams.json not found.")

    # 🔹 Load streams.json (secondary source)
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

    THUMBNAIL_DIR.mkdir(exist_ok=True)

    for video_id in sorted(all_video_ids):
        print(f"\nProcessing {video_id}")

        video_dir = THUMBNAIL_DIR / video_id
        video_dir.mkdir(exist_ok=True)

        jpg_path = video_dir / "thumbnail.jpg"
        hash_path = video_dir / "hash.txt"
        base64_path = video_dir / "thumbnail_base64.json"

        # 🚀 SPEED UPGRADE
        if jpg_path.exists() and hash_path.exists() and base64_path.exists():
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
