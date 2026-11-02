#!/usr/bin/env python3
"""Render the Agent Manager 31-second, 1080p promo video."""

from pathlib import Path
import subprocess

from create_promo import main as create_assets


HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "Agent-Manager-Promo-20260930.mp4"
SCENES = 7
SCENE_DURATION = 5.0
TRANSITION = 0.65
TOTAL = SCENES * SCENE_DURATION - (SCENES - 1) * TRANSITION


def render():
    create_assets()
    cmd = ["ffmpeg", "-hide_banner", "-y"]
    for i in range(1, SCENES + 1):
        cmd += ["-loop", "1", "-framerate", "30", "-t", "5",
                "-i", str(HERE / f"scene_{i:02}.png")]
    cmd += ["-i", str(HERE / "music.wav")]

    filters = []
    for i in range(SCENES):
        filters.append(
            f"[{i}:v]zoompan=z='min(zoom+0.00015,1.025)':"
            "x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
            "d=1:s=1920x1080:fps=30,"
            f"trim=duration={SCENE_DURATION},setpts=PTS-STARTPTS[v{i}]"
        )
    previous = "v0"
    for i in range(1, SCENES):
        offset = i * (SCENE_DURATION - TRANSITION)
        output = f"x{i}"
        filters.append(
            f"[{previous}][v{i}]xfade=transition=fade:"
            f"duration={TRANSITION}:offset={offset:.2f}[{output}]"
        )
        previous = output
    filters.append(
        f"[{previous}]fade=t=in:st=0:d=0.4,"
        f"fade=t=out:st={TOTAL-0.7:.2f}:d=0.7,"
        "format=yuv420p[vout]"
    )
    filters.append(
        f"[{SCENES}:a]afade=t=in:st=0:d=0.8,"
        f"afade=t=out:st={TOTAL-1.4:.2f}:d=1.4[aout]"
    )
    cmd += ["-filter_complex", ";".join(filters),
            "-map", "[vout]", "-map", "[aout]",
            "-c:v", "libx264", "-preset", "medium", "-crf", "20",
            "-pix_fmt", "yuv420p", "-r", "30",
            "-c:a", "aac", "-b:a", "192k", "-t", f"{TOTAL:.2f}",
            "-movflags", "+faststart", str(OUTPUT)]
    subprocess.run(cmd, check=True)
    print(f"Rendered {OUTPUT} ({TOTAL:.2f}s)")


if __name__ == "__main__":
    render()
