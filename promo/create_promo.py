#!/usr/bin/env python3
"""Create a privacy-safe Agent Manager promo from the shipped visual assets."""

from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = Path(__file__).resolve().parent
W, H = 1920, 1080
CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"
EN = "/System/Library/Fonts/Avenir Next.ttc"
ICON = ROOT / "Resources/AppIcon/AppIcon.png"

NAVY = (8, 17, 35)
INK = (20, 29, 50)
MUTED = (112, 126, 150)
BLUE = (39, 102, 235)
CYAN = (59, 210, 234)
MINT = (33, 191, 145)
LILAC = (108, 96, 236)
LIGHT = (244, 247, 252)
LINE = (222, 231, 241)


def font(size: int, english: bool = False):
    return ImageFont.truetype(EN if english else CN, size)


def text(draw, xy, value, size, fill, english=False, anchor=None):
    draw.text(xy, value, font=font(size, english), fill=fill, anchor=anchor,
              stroke_width=0)


def rounded(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius, fill=fill, outline=outline, width=width)


def gradient(top, bottom, glow=True):
    y = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    a = np.asarray(top, np.float32)[None, None, :]
    b = np.asarray(bottom, np.float32)[None, None, :]
    arr = np.broadcast_to(a * (1-y) + b*y, (H, W, 3)).copy()
    if glow:
        yy, xx = np.mgrid[0:H, 0:W]
        for cx, cy, rad, color, power in [
            (1470, 290, 610, (26, 110, 201), .22),
            (390, 900, 700, (64, 51, 143), .12),
        ]:
            z = np.exp(-((xx-cx)**2 + (yy-cy)**2)/(2*rad*rad))[..., None]
            arr += z * np.array(color)[None, None, :] * power
    return Image.fromarray(np.uint8(np.clip(arr, 0, 255)), "RGB").convert("RGBA")


def background():
    im = gradient((9, 19, 38), (5, 12, 29))
    d = ImageDraw.Draw(im, "RGBA")
    for x in range(0, W, 82):
        d.line((x, 0, x, H), fill=(125, 160, 225, 10), width=1)
    for y in range(0, H, 82):
        d.line((0, y, W, y), fill=(125, 160, 225, 10), width=1)
    return im


def pill(draw, box, label, color=(255, 255, 255), bg=(255, 255, 255, 23), size=27):
    rounded(draw, box, 24, bg)
    text(draw, ((box[0]+box[2])/2, (box[1]+box[3])/2), label, size, color,
         anchor="mm")


def app_icon(im, box):
    icon = Image.open(ICON).convert("RGBA")
    icon.thumbnail((box[2]-box[0], box[3]-box[1]), Image.Resampling.LANCZOS)
    x = int((box[0]+box[2]-icon.width)/2)
    y = int((box[1]+box[3]-icon.height)/2)
    im.alpha_composite(icon, (x, y))


def section(draw, number, category):
    text(draw, (125, 90), f"{number}  /  {category.upper()}", 28,
         (110, 194, 246), english=True)


def glow_card(im, box, fill=(255, 255, 255, 13), edge=(117, 181, 247, 65), rad=34):
    shadow = Image.new("RGBA", (W, H))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((box[0]+4, box[1]+14, box[2]+4, box[3]+14), rad,
                         fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(25))
    im.alpha_composite(shadow)
    d = ImageDraw.Draw(im, "RGBA")
    # ImageDraw replaces alpha on RGBA images, so use opaque glass tones here.
    rounded(d, box, rad, (25, 42, 69), (67, 111, 162), 2)


def slide1():
    im = background()
    d = ImageDraw.Draw(im, "RGBA")
    section(d, "01", "INTRO")
    pill(d, (126, 202, 430, 260), "macOS AI 能力控制台", (141, 223, 244),
         (41, 112, 181, 36), 25)
    text(d, (123, 355), "把 AI 能力，", 84, (255, 255, 255))
    text(d, (123, 465), "收进一处。", 104, (255, 255, 255))
    text(d, (130, 640), "统一查看与管理本机 Skills 和 MCP 服务", 35,
         (171, 191, 218))
    glow_card(im, (1220, 214, 1695, 722), (255, 255, 255, 15),
              (110, 186, 251, 80), 68)
    app_icon(im, (1297, 255, 1615, 573))
    d = ImageDraw.Draw(im, "RGBA")
    text(d, (1458, 650), "Agent Manager", 44, (255, 255, 255), True, "mm")
    for i, label in enumerate(("Skills", "MCP", "Presets")):
        pill(d, (126+i*220, 820, 310+i*220, 875), label,
             (213, 231, 249), (116, 166, 226, 31), 25)
    return im


def slide2():
    im = background()
    d = ImageDraw.Draw(im, "RGBA")
    section(d, "02", "OVERVIEW")
    text(d, (125, 192), "多个 AI 客户端", 77, (255, 255, 255))
    text(d, (125, 295), "一个界面看清。", 77, (255, 255, 255))
    text(d, (130, 427), "支持全局配置，也支持项目工作区", 32,
         (171, 191, 218))
    clients = ["Claude Code", "Codex", "Cursor", "Antigravity", "Qoder", "WorkBuddy"]
    points = [(220, 606), (747, 606), (1274, 606), (220, 788), (747, 788), (1274, 788)]
    colors = [(241, 149, 98), (137, 214, 226), (176, 188, 218),
              (152, 162, 247), (152, 220, 169), (90, 215, 185)]
    for (x, y), label, c in zip(points, clients, colors):
        glow_card(im, (x, y, x+425, y+134), (255, 255, 255, 15),
                  (198, 218, 244, 53), 25)
        d = ImageDraw.Draw(im, "RGBA")
        rounded(d, (x+27, y+32, x+97, y+102), 20, (*c, 225))
        text(d, (x+62, y+67), label[0], 42, (14, 28, 51), True, "mm")
        text(d, (x+120, y+67), label, 36, (242, 249, 255), True, "lm")
    return im


def ui_window(im, title, subtitle, selected="中央库 Skills"):
    # Faithful layout and colors from ManagerTheme, filled only with demo data.
    x0, y0, x1, y1 = 155, 225, 1765, 955
    d = ImageDraw.Draw(im, "RGBA")
    rounded(d, (x0, y0, x1, y1), 30, (245, 248, 252), (215, 227, 242), 2)
    d.rounded_rectangle((x0, y0, x0+295, y1), 28, fill=(235, 238, 244))
    d.rectangle((x0+270, y0, x0+295, y1), fill=(235, 238, 244))
    d.line((x0+295, y0, x0+295, y1), fill=LINE, width=2)
    for i, c in enumerate(((252, 101, 95), (255, 190, 64), (58, 205, 91))):
        d.ellipse((x0+27+i*29, y0+25, x0+45+i*29, y0+43), fill=c)
    app_icon(im, (x0+31, y0+78, x0+94, y0+141))
    d = ImageDraw.Draw(im, "RGBA")
    text(d, (x0+109, y0+100), "Agent Manager", 27, INK, True)
    text(d, (x0+109, y0+132), "AI 能力控制台", 17, MUTED)
    text(d, (x0+32, y0+195), "本地中央库", 20, MUTED)
    for i, label in enumerate(("中央库 Skills", "中央库 MCP", "预设组合",
                               "全部能力总览", "项目工作区", "设置")):
        yy = y0+234+i*72+(31 if i>2 else 0)
        if label == selected:
            rounded(d, (x0+18, yy-13, x0+277, yy+45), 16, (218, 235, 255))
        text(d, (x0+42, yy), label, 22, BLUE if label==selected else INK)
    text(d, (x0+343, y0+57), title, 46, INK)
    text(d, (x0+343, y0+116), subtitle, 22, MUTED)
    text(d, (x1-40, y0+68), "界面示意 · 演示数据", 17, MUTED, anchor="rm")
    return (x0+330, y0+166, x1-32, y1-30)


def skill_card(im, box, name, kind, desc, active):
    d = ImageDraw.Draw(im, "RGBA")
    rounded(d, box, 23, (255, 255, 255), LINE, 2)
    d.ellipse((box[0]+27, box[1]+30, box[0]+39, box[1]+42), fill=MINT)
    text(d, (box[0]+55, box[1]+22), name, 27, INK)
    pill(d, (box[2]-156, box[1]+22, box[2]-22, box[1]+62), kind,
         (86, 75, 209), (228, 225, 254), 18)
    rounded(d, (box[0]+26, box[1]+86, box[2]-26, box[1]+164), 14,
            (247, 250, 253))
    text(d, (box[0]+43, box[1]+110), desc, 20, MUTED)
    d.line((box[0]+27, box[1]+189, box[2]-27, box[1]+189), fill=LINE, width=2)
    for j, c in enumerate((BLUE, (33, 33, 39), (96, 109, 131),
                           (113, 126, 241), MINT)):
        xx = box[0]+28+j*47
        rounded(d, (xx, box[1]+211, xx+34, box[1]+245), 9,
                (*c, 45 if j>=active else 180))
        d.ellipse((xx+23, box[1]+240, xx+32, box[1]+249),
                  fill=MINT if j<active else (209, 216, 228))
    pill(d, (box[2]-170, box[1]+212, box[2]-26, box[1]+250),
         f"{active} 处启用", (28, 159, 116), (227, 248, 241), 18)


def slide3():
    im = background()
    d = ImageDraw.Draw(im, "RGBA")
    section(d, "03", "LIBRARY")
    text(d, (125, 140), "Skills 与 MCP，一屏总览", 59, (255, 255, 255))
    area = ui_window(im, "Skills 技能库", "本地中央存储与多客户端分发中枢")
    d = ImageDraw.Draw(im, "RGBA")
    rounded(d, (area[0], area[1], area[2], area[1]+63), 16,
            (255, 255, 255), LINE, 2)
    text(d, (area[0]+28, area[1]+17), "⌕   搜索能力名称、指令参数或详细说明…", 21, MUTED)
    card_y = area[1]+88
    cw = (area[2]-area[0]-26)//2
    skill_card(im, (area[0], card_y, area[0]+cw, card_y+275),
               "代码审查助手", "中央库 Skill", "审查代码并给出修改建议", 3)
    skill_card(im, (area[0]+cw+26, card_y, area[2], card_y+275),
               "文档整理", "中央库 Skill", "整理项目文档与知识笔记", 2)
    return im


def slide4():
    im = background()
    d = ImageDraw.Draw(im, "RGBA")
    section(d, "04", "DISTRIBUTE")
    text(d, (125, 184), "中央库存一次，", 76, (255, 255, 255))
    text(d, (125, 285), "按需分发到各客户端。", 76, (255, 255, 255))
    text(d, (130, 410), "Skill 通过软链接或复制部署；MCP 合并配置条目。", 30,
         (171, 191, 218))
    cx, cy = 960, 740
    destinations = [(330, 626, "Claude Code"), (680, 604, "Codex"),
                    (1240, 604, "Cursor"), (1590, 626, "Antigravity"),
                    (540, 894, "Qoder"), (1390, 894, "WorkBuddy")]
    for x,y,label in destinations:
        d.line((cx, cy, x, y), fill=(72, 160, 239, 125), width=4)
        d.ellipse((x-6,y-6,x+6,y+6), fill=CYAN)
        width=250 if len(label)<11 else 300
        rounded(d, (x-width//2,y-52,x+width//2,y+52), 24,
                (25,42,69), (67,111,162), 2)
        text(d, (x,y), label, 25, (241,248,255), True, "mm")
    glow_card(im, (838, 617, 1082, 863), (255,255,255,18),
              (111,197,254,155), 50)
    app_icon(im, (884, 655, 1036, 807))
    return im


def slide5():
    im = background()
    d = ImageDraw.Draw(im, "RGBA")
    section(d, "05", "PRESETS")
    text(d, (125, 140), "预设组合，快速切换工作配置", 59,
         (255,255,255))
    area = ui_window(im, "预设组合", "把 Skill 和 MCP 组成一套配置", "预设组合")
    d = ImageDraw.Draw(im, "RGBA")
    text(d, (area[0]+5, area[1]+18), "我的组合 · 2", 28, INK)
    rounded(d, (area[2]-210,area[1]+1,area[2],area[1]+58), 24, BLUE)
    text(d, (area[2]-105,area[1]+30), "+ 新建预设", 22,
         (255,255,255), anchor="mm")
    for i,(name,desc,skills,mcps) in enumerate([
        ("开发工作台", "日常开发与代码分析", "4 Skills", "2 MCP"),
        ("文档工作台", "文档整理与内容撰写", "3 Skills", "1 MCP")
    ]):
        x=area[0]+i*568
        y=area[1]+95
        rounded(d,(x,y,x+534,y+405),25,(255,255,255),LINE,2)
        rounded(d,(x+25,y+27,x+85,y+87),18,
                (229,236,255) if i==0 else (231,250,244))
        text(d,(x+55,y+57),"◆" if i==0 else "✦",29,
             BLUE if i==0 else MINT,anchor="mm")
        text(d,(x+103,y+33),name,31,INK)
        text(d,(x+28,y+110),desc,21,MUTED)
        pill(d,(x+27,y+173,x+186,y+221),skills,(66,90,173),(233,239,255),20)
        pill(d,(x+203,y+173,x+350,y+221),mcps,(66,90,173),(233,239,255),20)
        d.line((x+27,y+260,x+507,y+260),fill=LINE,width=2)
        text(d,(x+28,y+295),"目标客户端   Codex · Cursor",20,MUTED)
        rounded(d,(x+299,y+333,x+504,y+382),19,BLUE)
        text(d,(x+402,y+357),"预览并应用",20,(255,255,255),anchor="mm")
    return im


def slide6():
    im = background()
    d = ImageDraw.Draw(im, "RGBA")
    section(d, "06", "CONTROL")
    text(d, (125, 185), "来源清晰，变更可追溯。", 72,
         (255,255,255))
    text(d, (128, 293), "部署前看目标位置，操作后查记录与回滚。", 32,
         (171,191,218))
    labels=[("本应用分发","谁管理，一眼可见",CYAN),
            ("客户端已有","原有配置清楚区分",MINT),
            ("系统服务","系统内置保持只读",(179,176,250))]
    for i,(title,detail,c) in enumerate(labels):
        x=153+i*554
        glow_card(im,(x,470,x+510,760),(255,255,255,18),
                  (130,185,238,76),28)
        d=ImageDraw.Draw(im,"RGBA")
        d.ellipse((x+34,520,x+60,546),fill=c)
        text(d,(x+79,507),title,35,(255,255,255))
        text(d,(x+35,590),detail,27,(171,191,218))
        pill(d,(x+35,668,x+322,718),"本机操作记录",(210,231,255),
             (100,161,221,37),21)
    text(d,(960,858),"本地管理 · 配置备份 · 可回滚操作",31,
         (195,216,240),anchor="mm")
    return im


def slide7():
    im=background()
    glow_card(im,(785,162,1135,510),(255,255,255,16),
              (139,200,250,90),72)
    app_icon(im,(852,202,1068,418))
    d=ImageDraw.Draw(im,"RGBA")
    text(d,(960,580),"Agent Manager",82,(255,255,255),True,"mm")
    text(d,(960,711),"让 AI 能力管理，简单一点。",55,
         (223,237,255),anchor="mm")
    pill(d,(560,810,1360,878),"macOS  ·  本地中央库  ·  多客户端分发",
         (180,214,244),(102,159,221,33),27)
    return im


def make_music(seconds=31.0):
    sr=44100
    n=int(seconds*sr)
    t=np.arange(n,dtype=np.float64)/sr
    out=np.zeros(n,dtype=np.float64)
    chords=[(130.81,164.81,196.00),(110.00,130.81,164.81),
            (87.31,130.81,174.61),(98.00,146.83,196.00)]
    duration=seconds/len(chords)
    for k,chord in enumerate(chords):
        a=int(k*duration*sr); b=int(min(n,(k+1)*duration*sr))
        tt=t[a:b]
        local=tt-k*duration
        fade=np.minimum(1,np.minimum(local/1.5,(duration-local)/1.5))
        fade=np.maximum(0,fade)
        for frequency in chord:
            out[a:b]+=0.027*np.sin(2*np.pi*frequency*tt)*fade
            out[a:b]+=0.006*np.sin(2*np.pi*frequency*2*tt)*fade
    # An original, restrained pulse gives the cuts a sense of pace.
    for beat in np.arange(.3,seconds,0.9):
        a=int(beat*sr); b=min(n,a+int(.17*sr))
        u=np.arange(b-a)/sr
        out[a:b]+=0.035*np.sin(2*np.pi*(160-100*u)*u)*np.exp(-27*u)
    fadeout=np.minimum(1,(seconds-t)/1.3)
    out*=np.clip(fadeout,0,1)
    audio=np.int16(np.clip(out,-.85,.85)*32767)
    with wave.open(str(OUT/"music.wav"),"wb") as wf:
        wf.setnchannels(2);wf.setsampwidth(2);wf.setframerate(sr)
        wf.writeframes(np.column_stack([audio,audio]).tobytes())


def main():
    OUT.mkdir(exist_ok=True)
    slides=[slide1(),slide2(),slide3(),slide4(),slide5(),slide6(),slide7()]
    for i,im in enumerate(slides,1):
        im.convert("RGB").save(OUT/f"scene_{i:02}.png",optimize=True)
    make_music()
    thumbs=[]
    for im in slides:
        a=im.convert("RGB");a.thumbnail((480,270))
        thumbs.append(a)
    sheet=Image.new("RGB",(480*2,270*4),(12,20,36))
    for i,im in enumerate(thumbs):
        sheet.paste(im,((i%2)*480,(i//2)*270))
    sheet.save(OUT/"storyboard.jpg",quality=91)
    slides[-1].convert("RGB").save(OUT/"cover.jpg",quality=94)
    print(f"Created {len(slides)} scenes and original music in {OUT}")


if __name__=="__main__":
    main()
