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

    # Find downloaded thumbnail (yt-dlp auto names it)
    for file in output_dir.glob(f"{video_id}.*"):
        if file.suffix.lower() in [".jpg", ".jpeg", ".webp", ".png"]:
            return file

    return None

def convert_to_png(input_path, output_path):
    with Image.open(input_path) as img:
        img.save(output_path, format="PNG")

def encode_base64(image_path):
    with open(image_path, "rb") as f:
        encoded = base64.b64encode(f.read()).decode("utf-8")
    return encoded

def main():
    if not Path(STREAMS_FILE).exists():
        print("streams.json not found.")
        return

    with open(STREAMS_FILE, "r", encoding="utf-8") as f:
        streams = json.load(f)

    THUMBNAIL_DIR.mkdir(exist_ok=True)

    for stream in streams:
        video_id = stream.get("video_id")
        if not video_id:
            continue

        print(f"Processing {video_id}")

        video_dir = THUMBNAIL_DIR / video_id
        video_dir.mkdir(exist_ok=True)

        png_path = video_dir / "thumbnail.png"
        hash_path = video_dir / "hash.txt"
        base64_path = video_dir / "thumbnail_base64.json"

        temp_file = download_thumbnail(video_id, video_dir)
        if not temp_file:
            print(f"Failed to download thumbnail for {video_id}")
            continue

        convert_to_png(temp_file, png_path)
        temp_file.unlink(missing_ok=True)

        if png_path.stat().st_size > MAX_SIZE:
            print(f"Thumbnail too large for {video_id}")
            png_path.unlink(missing_ok=True)
            continue

        new_hash = sha256_file(png_path)

        if hash_path.exists():
            old_hash = hash_path.read_text().strip()
            if old_hash == new_hash:
                print("Thumbnail unchanged, skipping base64 update.")
                continue

        hash_path.write_text(new_hash)

        encoded = encode_base64(png_path)

        with open(base64_path, "w", encoding="utf-8") as f:
            json.dump({
                "video_id": video_id,
                "mime_type": "image/png",
                "base64": encoded
            }, f)

        print(f"Updated thumbnail + base64 for {video_id}")

if __name__ == "__main__":
    main()
