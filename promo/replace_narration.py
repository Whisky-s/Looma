#!/usr/bin/env python3
"""Replace the promo narration with Mandarin neural speech."""

import asyncio
import json
from pathlib import Path
import subprocess
import sys
import wave

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / '.tts-deps'))
import edge_tts

VOICE = 'zh-CN-XiaoxiaoNeural'
OUT = HERE / 'neural_voice'
SOURCE = HERE / 'Agent-Manager-Promo-Real-UI-20260930.mp4'
OUTPUT = HERE / 'Agent-Manager-Promo-Natural-Voice-20260930.mp4'
LINES = [
    'Agent Manager，把分散的 AI 能力，收进一处。',
    '多个 AI 客户端，启用了什么，一眼就能看清。',
    'MCP 服务集中收纳，来源和状态，一目了然。',
    '把常用技能和服务存成组合，下次直接复用。',
    '应用前先预览变更，确认后，再执行。',
    '每次操作都有记录，配置变更，可以追溯。',
    'Agent Manager，让本机 AI 能力管理，更简单。',
]


def read_pcm(mp3, wav):
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(mp3),
                    '-ac', '1', '-ar', '48000', '-c:a', 'pcm_s16le', str(wav)], check=True)
    with wave.open(str(wav), 'rb') as f:
        data = np.frombuffer(f.readframes(f.getnframes()), dtype=np.int16).astype(np.float32) / 32768
    voiced = np.flatnonzero(np.abs(data) > .0015)
    if len(voiced):
        data = data[max(0, voiced[0]-4800):min(len(data), voiced[-1]+12000)]
    return data


async def main():
    OUT.mkdir(exist_ok=True)
    sr = 48000
    full = np.zeros(39*sr, dtype=np.float32)
    manifest = []
    for i, line in enumerate(LINES):
        mp3 = OUT / f'scene_{i+1:02}.mp3'
        wav = OUT / f'scene_{i+1:02}.wav'
        rate = -4
        for attempt in range(3):
            await edge_tts.Communicate(line, VOICE, rate=f'{rate:+d}%').save(str(mp3))
            data = read_pcm(mp3, wav)
            duration = len(data)/sr
            if duration <= 4.95:
                break
            rate = int((1+rate/100)*duration/4.75*100-100)
        if duration > 5.0:
            raise RuntimeError(f'Scene {i+1} narration too long: {duration}')
        start = int((i*5.5+.55)*sr)
        end = start+len(data)
        full[start:end] = data
        manifest.append({'scene':i+1,'voice':VOICE,'text':line,'start':start/sr,'duration':duration,'rate':rate})
        print(f'Scene {i+1}: {duration:.2f}s at {rate:+d}%', flush=True)
    # One stable level for all sentences, with headroom for AAC encoding.
    peak = float(np.max(np.abs(full)))
    if peak:
        full *= .78/peak
    track = OUT / 'narration.wav'
    with wave.open(str(track), 'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr)
        f.writeframes((np.clip(full,-1,1)*32767).astype(np.int16).tobytes())
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(SOURCE),'-i',str(track),
                    '-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','192k',
                    '-t','39','-movflags','+faststart',str(OUTPUT)],check=True)
    subprocess.run(['ffmpeg','-loglevel','error','-y','-i',str(track),'-t','11',
                    '-c:a','libmp3lame','-b:a','192k',str(OUT/'preview.mp3')],check=True)
    print(OUTPUT, flush=True)


if __name__ == '__main__':
    asyncio.run(main())
