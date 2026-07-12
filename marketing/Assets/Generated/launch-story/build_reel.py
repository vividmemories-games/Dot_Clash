#!/usr/bin/env python3
"""Build the 7-panel Dot Clash launch Reel (1080x1920, ~22s)."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

OUT_DIR = Path(__file__).resolve().parent
OUT_FILE = OUT_DIR / "dot-clash-launch-story-reel.mp4"
TMP_DIR = OUT_DIR / ".reel_tmp"

WIDTH = 1080
HEIGHT = 1920
FPS = 30
FADE = 0.5

IMAGES = [
    OUT_DIR / "01-before-smartphones.png",
    OUT_DIR / "02-papa-can-we-play.png",
    OUT_DIR / "03-simple-moment-idea.png",
    OUT_DIR / "04-late-nights-dream.png",
    OUT_DIR / "05-childhood-reimagined.png",
    OUT_DIR / "06-is-now-live.png",
    OUT_DIR / "07-share-the-memory.png",
]
DURATIONS = [3, 3, 3, 3, 3, 5, 5]


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True)


def clip_path(index: int) -> Path:
    return TMP_DIR / f"clip_{index:02d}.mp4"


def render_clips() -> list[Path]:
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    vf = (
        f"scale={WIDTH}:{HEIGHT}:force_original_aspect_ratio=decrease,"
        f"pad={WIDTH}:{HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=0x101A28,"
        "format=yuv420p"
    )
    clips: list[Path] = []
    for i, (image, duration) in enumerate(zip(IMAGES, DURATIONS)):
        if not image.exists():
            raise FileNotFoundError(image)
        out = clip_path(i)
        run(
            [
                "ffmpeg",
                "-y",
                "-loop",
                "1",
                "-i",
                str(image),
                "-t",
                str(duration),
                "-vf",
                vf,
                "-r",
                str(FPS),
                "-c:v",
                "libx264",
                "-preset",
                "fast",
                "-crf",
                "20",
                "-pix_fmt",
                "yuv420p",
                "-an",
                str(out),
            ]
        )
        clips.append(out)
    return clips


def xfade_merge(clips: list[Path], out: Path) -> None:
    inputs: list[str] = []
    for clip in clips:
        inputs.extend(["-i", str(clip)])

    filter_parts: list[str] = []
    offsets: list[float] = []
    cumulative = 0.0
    for k, duration in enumerate(DURATIONS[:-1]):
        cumulative += duration
        offsets.append(cumulative - (k + 1) * FADE)

    prev = "[0:v]"
    for i in range(1, len(clips)):
        current = f"[{i}:v]"
        out_label = f"[v{i}]"
        filter_parts.append(
            f"{prev}{current}xfade=transition=fade:duration={FADE}:offset={offsets[i-1]:.3f}{out_label}"
        )
        prev = out_label

    filter_complex = ";".join(filter_parts)
    run(
        [
            "ffmpeg",
            "-y",
            *inputs,
            "-filter_complex",
            filter_complex,
            "-map",
            prev,
            "-c:v",
            "libx264",
            "-preset",
            "medium",
            "-crf",
            "20",
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
            "-an",
            str(out),
        ]
    )


def main() -> int:
    if shutil.which("ffmpeg") is None:
        print("ffmpeg not found", file=sys.stderr)
        return 1

    if OUT_FILE.exists():
        OUT_FILE.unlink()
    if TMP_DIR.exists():
        shutil.rmtree(TMP_DIR)

    clips = render_clips()
    xfade_merge(clips, OUT_FILE)
    shutil.rmtree(TMP_DIR)

    total = sum(DURATIONS) - (len(DURATIONS) - 1) * FADE
    print(f"Done: {OUT_FILE} ({total:.1f}s, {WIDTH}x{HEIGHT}, silent)")
    print("Add music in Instagram/Facebook Reels editor (warm piano → beat on panel 6).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
