#!/usr/bin/env python3
"""Render a narrated Agent Manager promo from real app screenshots."""

from __future__ import annotations

import subprocess
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
CAPTURES = HERE / "captures"
FRAMES = HERE / "real_frames"
VOICE = HERE / "real_voice"
OUTPUT = HERE / "Agent-Manager-Promo-Real-UI-20260930.mp4"
W, H = 1920, 1080
SCENE_DURATION = 6.0
TRANSITION = 0.5
STEP = SCENE_DURATION - TRANSITION
FPS = 30
TOTAL = 7 * SCENE_DURATION - 6 * TRANSITION
CN_FONT = "/System/Library/Fonts/Hiragino Sans GB.ttc"
EN_FONT = "/System/Library/Fonts/Avenir Next.ttc"

SCENES = [
    {
        "source": "current-app.png",
        "eyebrow": "AGENT MANAGER  /  01",
        "title": "把 AI 能力，收进一处",
        "detail": "本机 Skills 与 MCP 服务，一屏统览",
        "voice": "Agent Manager，把分散的 AI 能力，收进一处。",
        "kind": "intro",
    },
    {
        "source": "codex-view.png",
        "eyebrow": "CLIENTS  /  02",
        "title": "按客户端查看能力",
        "detail": "Codex、Claude Code、Cursor 等客户端，各自状态清晰可见",
        "voice": "按客户端查看技能配置和启用状态，管理起来更直观。",
    },
    {
        "source": "mcp.png",
        "eyebrow": "MCP  /  03",
        "title": "MCP 服务集中管理",
        "detail": "服务清单、来源与可用状态，集中呈现",
        "voice": "MCP 服务集中展示，来源和状态一目了然。",
    },
    {
        "source": "presets.png",
        "eyebrow": "PRESETS  /  04",
        "title": "常用能力，保存成组合",
        "detail": "把 Skills 和 MCP 服务整理为可复用的预设",
        "voice": "把常用技能和服务，保存成可复用的预设组合。",
    },
    {
        "source": "preset-preview.png",
        "eyebrow": "PREVIEW  /  05",
        "title": "应用前，先看清变化",
        "detail": "选择目标客户端，预览将启用、停用或保留的配置",
        "voice": "应用组合之前，先预览每项配置将如何变化。",
    },
    {
        "source": "history.png",
        "eyebrow": "HISTORY  /  06",
        "title": "每次操作，都有记录",
        "detail": "在操作记录中追溯变更，并查看可回滚的项目",
        "voice": "每次配置变更都有记录，需要时还能查看回滚入口。",
    },
    {
        "source": "current-app.png",
        "eyebrow": "AGENT MANAGER",
        "title": "让本机 AI 能力管理更简单",
        "detail": "Skills · MCP · 预设组合 · 多客户端",
        "voice": "Agent Manager，让本机 AI 能力管理更简单。",
        "kind": "outro",
    },
]


def font(size: int, english: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(EN_FONT if english else CN_FONT, size)


def screenshot(name: str) -> Image.Image:
    source = Image.open(CAPTURES / name).convert("RGB")
    # screencapture -l records the full display with black outside the window.
    array = np.asarray(source)
    mask = np.max(array, axis=2) > 20
    yy, xx = np.nonzero(mask)
    return source.crop((int(xx.min()), int(yy.min()), int(xx.max()) + 1, int(yy.max()) + 1))


def cover(base: Image.Image, source: Image.Image, x: int, y: int, width: int, height: int) -> None:
    scale = max(width / source.width, height / source.height)
    resized = source.resize((int(source.width * scale + 0.5), int(source.height * scale + 0.5)), Image.Resampling.LANCZOS)
    ox = (resized.width - width) // 2
    oy = (resized.height - height) // 2
    base.paste(resized.crop((ox, oy, ox + width, oy + height)), (x, y))


def gradient_overlay(im: Image.Image, start: int, opacity: int = 244) -> None:
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    arr = np.zeros((H, W, 4), dtype=np.uint8)
    arr[:, :, :3] = (7, 17, 35)
    yy = np.arange(H)
    alpha = np.clip((yy - start) / max(1, H - start), 0, 1) ** 0.72
    arr[:, :, 3] = np.uint8(alpha[:, None] * opacity)
    overlay = Image.fromarray(arr, "RGBA")
    im.alpha_composite(overlay)


def render_scene(index: int, scene: dict) -> Path:
    shot = screenshot(scene["source"])
    kind = scene.get("kind")
    im = Image.new("RGBA", (W, H), (7, 17, 35, 255))
    if kind:
        cover(im, shot, 0, 0, W, H)
        blur = im.filter(ImageFilter.GaussianBlur(13))
        shade = Image.new("RGBA", (W, H), (4, 13, 30, 174))
        im = Image.alpha_composite(blur, shade)
        icon = Image.open(ROOT / "Resources/AppIcon/AppIcon.png").convert("RGBA")
        icon.thumbnail((134, 134), Image.Resampling.LANCZOS)
        im.alpha_composite(icon, (111, 194))
        d = ImageDraw.Draw(im)
        d.text((111, 371), scene["eyebrow"], font=font(25, True), fill=(130, 201, 255))
        d.text((105, 432), scene["title"], font=font(82 if kind == "intro" else 72), fill="white")
        d.text((111, 575), scene["detail"], font=font(34), fill=(210, 226, 242))
        d.rounded_rectangle((111, 717, 476, 780), radius=30, fill=(35, 107, 229))
        d.text((293, 748), "macOS  AI 能力控制台", font=font(25), fill="white", anchor="mm")
    else:
        # Real window dominates the frame; the lower third carries readable context.
        shot.thumbnail((1870, 1030), Image.Resampling.LANCZOS)
        x = (W - shot.width) // 2
        y = 23
        im.paste(shot, (x, y))
        gradient_overlay(im, 695)
        d = ImageDraw.Draw(im)
        d.text((96, 829), scene["eyebrow"], font=font(23, True), fill=(117, 194, 255))
        d.text((92, 878), scene["title"], font=font(61), fill="white")
        d.text((96, 976), scene["detail"], font=font(31), fill=(211, 227, 243))
        d.rounded_rectangle((1802, 920, 1812, 1020), radius=5, fill=(74, 161, 255))
    path = FRAMES / f"scene_{index:02}.png"
    im.convert("RGB").save(path, optimize=True)
    return path


def voice_track() -> Path:
    sr = 44100
    full = np.zeros(int(TOTAL * sr), dtype=np.float32)
    for i, scene in enumerate(SCENES):
        aiff = VOICE / f"scene_{i+1:02}.aiff"
        wav = VOICE / f"scene_{i+1:02}.wav"
        subprocess.run(["say", "-v", "Tingting", "-r", "190", "-o", str(aiff), scene["voice"]], check=True)
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(aiff), "-ac", "1", "-ar", str(sr), "-c:a", "pcm_s16le", str(wav)], check=True)
        with wave.open(str(wav), "rb") as f:
            data = np.frombuffer(f.readframes(f.getnframes()), dtype=np.int16).astype(np.float32) / 32768
        # Remove TTS lead and tail silence; preserve a natural short pause.
        voiced = np.flatnonzero(np.abs(data) > 0.0015)
        if len(voiced):
            data = data[max(0, voiced[0] - int(.1 * sr)):min(len(data), voiced[-1] + int(.3 * sr))]
        edge = min(int(.08 * sr), len(data) // 2)
        if edge:
            data[:edge] *= np.linspace(0, 1, edge)
            data[-edge:] *= np.linspace(1, 0, edge)
        start = int((i * STEP + .72) * sr)
        end = min(start + len(data), len(full))
        full[start:end] += data[:end-start]
        print(f"Scene {i+1}: narration {len(data)/sr:.2f}s, starts {start/sr:.2f}s")
    peak = float(np.max(np.abs(full)))
    if peak:
        full *= min(1.0, .82 / peak)
    path = VOICE / "narration.wav"
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes((np.clip(full, -1, 1) * 32767).astype(np.int16).tobytes())
    return path


def render_video(frames: list[Path], audio: Path) -> None:
    cmd = ["ffmpeg", "-hide_banner", "-y"]
    for frame in frames:
        cmd += ["-loop", "1", "-framerate", str(FPS), "-t", str(SCENE_DURATION), "-i", str(frame)]
    cmd += ["-i", str(audio)]
    filters = []
    for i in range(len(frames)):
        filters.append(
            f"[{i}:v]zoompan=z='min(zoom+0.00009,1.015)':"
            "x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':"
            f"d=1:s={W}x{H}:fps={FPS},trim=duration={SCENE_DURATION},"
            f"setpts=PTS-STARTPTS[v{i}]"
        )
    prev = "v0"
    for i in range(1, len(frames)):
        out = f"x{i}"
        filters.append(f"[{prev}][v{i}]xfade=transition=fade:duration={TRANSITION}:offset={i*STEP:.2f}[{out}]")
        prev = out
    filters.append(f"[{prev}]fade=t=in:st=0:d=0.35,fade=t=out:st={TOTAL-.65:.2f}:d=0.65,format=yuv420p[vout]")
    cmd += ["-filter_complex", ";".join(filters), "-map", "[vout]", "-map", f"{len(frames)}:a",
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "19", "-pix_fmt", "yuv420p",
            "-r", str(FPS), "-c:a", "aac", "-b:a", "192k", "-t", str(TOTAL),
            "-movflags", "+faststart", str(OUTPUT)]
    subprocess.run(cmd, check=True)
    print(OUTPUT)


def main() -> None:
    FRAMES.mkdir(exist_ok=True)
    VOICE.mkdir(exist_ok=True)
    frames = [render_scene(i, scene) for i, scene in enumerate(SCENES, 1)]
    audio = voice_track()
    render_video(frames, audio)


if __name__ == "__main__":
    main()
