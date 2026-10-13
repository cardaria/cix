import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


metadata_path = Path(os.environ["MODEL_METADATA"])
metadata = json.loads(metadata_path.read_text())
target = Path(os.environ["MODEL_CHECKPOINT"])
files = metadata["files"]
marker = target / ".verified"
cache_home = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
hf_home = Path(os.environ.get("HF_HOME", cache_home / "huggingface"))
cache = Path(os.environ.get("HF_HUB_CACHE", hf_home / "hub"))
snapshot = cache / ("models--" + metadata["id"].replace("/", "--")) / "snapshots" / metadata["sha"]


def verify(path, item):
    if path.stat().st_size != item["size"]:
        raise ValueError(f"Size mismatch: {path}")
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        while chunk := stream.read(8 * 1024 * 1024):
            digest.update(chunk)
    if digest.hexdigest() != item["sha256"]:
        raise ValueError(f"Hash mismatch: {path}")
    print(f'Verified: {item["name"]}', flush=True)


def fetch():
    target.mkdir(parents=True, exist_ok=True)
    marker.unlink(missing_ok=True)
    for item in files:
        name = item["name"]
        destination = target / name
        if destination.exists():
            verify(destination, item)
            continue
        partial = target / (name + ".part")
        cached = snapshot / name
        if cached.is_file():
            verify(cached, item)
            # Reflinks preserve the cache while avoiding another copy of the weights
            subprocess.run(["cp", "--reflink=auto", str(cached.resolve()), str(partial)], check=True)
        else:
            url = f'https://huggingface.co/{metadata["id"]}/resolve/{metadata["sha"]}/{name}'
            subprocess.run(["curl", "--fail", "--location", "--retry", "5",
                            "--continue-at", "-", "--output", str(partial), url], check=True)
            try:
                verify(partial, item)
            except ValueError:
                # A bad file would otherwise be resumed on every retry
                partial.unlink()
                raise
        partial.replace(destination)
    marker.write_text(metadata["sha"] + "\n")
    print(f"Model ready: {target}")


def main():
    command = sys.argv[1]
    if command == "status":
        ready = marker.is_file() and marker.read_text().strip() == metadata["sha"]
        print(f'Model: {metadata["id"]}\nRevision: {metadata["sha"]}\nPath: {target}')
        print("Verified" if ready else "Missing or unverified: run cix ocr fetch")
        return 0 if ready else 1
    if command == "fetch":
        fetch()
    else:
        marker.unlink(missing_ok=True)
        for item in files:
            verify(target / item["name"], item)
        marker.write_text(metadata["sha"] + "\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
