import os
import json
import hashlib
import base64
from pathlib import Path
from yt_dlp import YoutubeDL
from PIL import Image

STREAMS_FILE = "data/streams.json"
THUMBNAIL_DIR = Path("thumbnails")
MAX_SIZE = 10 * 1024 * 1024  # 10MB

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()

def download_thumbnail(video_id, output_dir):
    url = f"https://www.youtube.com/watch?v={video_id}"

    ydl_opts = {
        "skip_download": True,
        "writethumbnail": True,
        "outtmpl": str(output_dir / "%(id)s"),
        "quiet": True,
    }

    with YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

    # find downloaded thumbnail
    for file in output_dir.glob(f"{video_id}.*"):
        if file.suffix.lower() in [".jpg", ".jpeg", ".webp", ".png"]:
            return file

    return None

def convert_to_jpg(input_path, output_path):
    with Image.open(input_path) as img:
        rgb = img.convert("RGB")
        rgb.save(output_path, format="JPEG", quality=95)

def encode_base64(image_path):
    with open(image_path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")

def extract_video_ids(streams_data):
    video_ids = []

    if isinstance(streams_data, list):
        for item in streams_data:
            if isinstance(item, str):
                video_ids.append(item)
            elif isinstance(item, dict):
                if "video_id" in item:
                    video_ids.append(item["video_id"])
    elif isinstance(streams_data, dict):
        video_ids.extend(streams_data.keys())

    return video_ids

def main():
    if not Path(STREAMS_FILE).exists():
        print("streams.json not found.")
        return

    with open(STREAMS_FILE, "r", encoding="utf-8") as f:
        streams_data = json.load(f)

    video_ids = extract_video_ids(streams_data)

    if not video_ids:
        print("No video IDs found.")
        return

    THUMBNAIL_DIR.mkdir(exist_ok=True)

    for video_id in video_ids:
        print(f"Processing {video_id}")

        video_dir = THUMBNAIL_DIR / video_id
        video_dir.mkdir(exist_ok=True)

        jpg_path = video_dir / "thumbnail.jpg"
        hash_path = video_dir / "hash.txt"
        base64_path = video_dir / "thumbnail_base64.json"

        temp_file = download_thumbnail(video_id, video_dir)
        if not temp_file:
            print(f"Failed to download thumbnail for {video_id}")
            continue

        convert_to_jpg(temp_file, jpg_path)
        temp_file.unlink(missing_ok=True)

        if jpg_path.stat().st_size > MAX_SIZE:
            print(f"Thumbnail too large for {video_id}")
            jpg_path.unlink(missing_ok=True)
            continue

        new_hash = sha256_file(jpg_path)

        if hash_path.exists():
            old_hash = hash_path.read_text().strip()
            if old_hash == new_hash:
                print("Unchanged. Skipping base64 update.")
                continue

        hash_path.write_text(new_hash)

        encoded = encode_base64(jpg_path)

        with open(base64_path, "w", encoding="utf-8") as f:
            json.dump({
                "video_id": video_id,
                "mime_type": "image/jpeg",
                "base64": encoded
            }, f)

        print(f"Updated thumbnail + base64 for {video_id}")

if __name__ == "__main__":
    main()
