#!/usr/bin/env python3
"""Generate readable local PNG previews for the Xiguang Flutter prototype.

The actual app is implemented in Flutter under lib/main.dart. This helper exists
only because the current machine does not have a complete Xcode/Android SDK
toolchain, so interactive Flutter preview cannot launch here yet.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "preview"
WIDTH, HEIGHT = 390, 844

COLORS = {
    "paper": (246, 243, 236),
    "white": (255, 252, 246),
    "ink": (35, 51, 50),
    "muted": (120, 130, 125),
    "line": (228, 221, 208),
    "green": (114, 165, 143),
    "blue": (158, 187, 204),
    "coral": (233, 161, 139),
    "lilac": (217, 204, 232),
    "cream": (248, 236, 225),
}


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc"
        if weight == "bold"
        else "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/Supplemental/Songti.ttc",
    ]
    for item in candidates:
        path = Path(item)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


F = {
    "eyebrow": font(11, "bold"),
    "hero": font(34, "bold"),
    "h2": font(18, "bold"),
    "h3": font(15, "bold"),
    "body": font(14),
    "small": font(12),
    "nav": font(11, "bold"),
    "inverse": font(20, "bold"),
}


def text_wrap(draw: ImageDraw.ImageDraw, text: str, font_obj, max_width: int) -> list[str]:
    lines: list[str] = []
    current = ""
    for char in text:
        trial = current + char
        if draw.textlength(trial, font=font_obj) <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = char
    if current:
        lines.append(current)
    return lines


def draw_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    font_obj,
    fill=COLORS["ink"],
    max_width: int | None = None,
    line_gap: int = 5,
) -> int:
    x, y = xy
    if max_width is None:
        draw.text((x, y), text, font=font_obj, fill=fill)
        return y + font_obj.size + line_gap
    for line in text_wrap(draw, text, font_obj, max_width):
        draw.text((x, y), line, font=font_obj, fill=fill)
        y += font_obj.size + line_gap
    return y


def card(draw: ImageDraw.ImageDraw, box, fill=COLORS["white"], outline=COLORS["line"]):
    x1, y1, x2, y2 = box
    shadow = (35, 65, 63, 24)
    for offset, alpha in [(14, 14), (8, 10)]:
        draw.rounded_rectangle((x1, y1 + offset, x2, y2 + offset), radius=8, fill=shadow)
    draw.rounded_rectangle(box, radius=8, fill=fill, outline=outline, width=1)


def chip(draw, x, y, label, selected=False):
    fill = COLORS["green"] if selected else COLORS["white"]
    color = (255, 255, 255) if selected else COLORS["ink"]
    w = int(draw.textlength(label, font=F["small"])) + 24
    draw.rounded_rectangle((x, y, x + w, y + 32), radius=8, fill=fill, outline=COLORS["line"])
    draw.text((x + 12, y + 8), label, font=F["small"], fill=color)
    return x + w + 8


def background() -> Image.Image:
    img = Image.new("RGBA", (WIDTH, HEIGHT), COLORS["paper"] + (255,))
    draw = ImageDraw.Draw(img, "RGBA")
    for y in range(0, HEIGHT):
        t = y / HEIGHT
        r = int(COLORS["paper"][0] * (1 - t) + COLORS["cream"][0] * t)
        g = int(COLORS["paper"][1] * (1 - t) + COLORS["cream"][1] * t)
        b = int(COLORS["paper"][2] * (1 - t) + COLORS["cream"][2] * t)
        draw.line((0, y, WIDTH, y), fill=(r, g, b, 255))
    for i in range(7):
        y = 80 + i * 88
        points = []
        for x in range(-10, WIDTH + 20, 18):
            points.append((x, y + math.sin(x / 32 + i) * 5))
        draw.line(points, fill=COLORS["green"] + (26,), width=1)
    return img


def header(draw, title: str, subtitle: str, label: str):
    draw.text((22, 18), label, font=F["eyebrow"], fill=COLORS["green"])
    draw.text((22, 42), title, font=F["hero"], fill=COLORS["ink"])
    draw.ellipse((326, 38, 368, 80), fill=(255, 252, 246, 220))
    draw.text((338, 47), "月", font=F["h3"], fill=COLORS["ink"])
    draw_text(draw, (22, 92), subtitle, F["body"], COLORS["ink"], 315)


def nav(draw, selected: int):
    labels = ["记录", "时间线", "小宇宙", "我的"]
    icons = ["✎", "⌁", "✦", "○"]
    card(draw, (18, 750, 372, 825), fill=(255, 252, 246))
    for i, label in enumerate(labels):
        x = 34 + i * 86
        if i == selected:
            draw.rounded_rectangle((x - 10, 760, x + 72, 818), radius=8, fill=(232, 241, 236))
        fill = COLORS["green"] if i == selected else COLORS["muted"]
        draw.text((x + 20, 768), icons[i], font=F["h2"], fill=fill)
        draw.text((x + 13, 797), label, font=F["nav"], fill=COLORS["ink"])


def draw_hero_card(draw):
    box = (22, 134, 368, 342)
    draw.rounded_rectangle(box, radius=8, fill=(80, 126, 116))
    for i in range(11):
        y = 166 + i * 15
        pts = [(x, y + math.sin(x / 34 + i * 0.5) * 5) for x in range(22, 369, 18)]
        draw.line(pts, fill=(255, 255, 255, 45), width=1)
    draw.ellipse((228, 166, 338, 276), outline=(255, 255, 255, 120), width=1)
    draw.ellipse((255, 193, 311, 249), fill=(255, 255, 255, 170))
    draw_text(draw, (42, 225), "这一束光，已经落进你的宇宙。", F["inverse"], (255, 255, 255), 160)
    draw_text(draw, (42, 287), "今晚的节律：缓慢、轻、没有任务。", F["body"], (255, 255, 255), 185)


def fragment_card(draw, y: int, color, title, text, tags, time="23:48"):
    card(draw, (22, y, 368, y + 140))
    draw.rounded_rectangle((42, y + 18, 98, y + 74), radius=8, fill=color)
    draw.ellipse((62, y + 35, 82, y + 55), outline=(255, 255, 255), width=2)
    draw.line((54, y + 64, 90, y + 28), fill=(255, 255, 255), width=2)
    draw.text((112, y + 18), title, font=F["h3"], fill=COLORS["ink"])
    draw.text((291, y + 22), time, font=F["small"], fill=COLORS["muted"])
    draw_text(draw, (112, y + 45), text, F["body"], COLORS["ink"], 225)
    x = 112
    for i, tag in enumerate(tags):
        x = chip(draw, x, y + 100, tag, selected=i == 0)


def capture_screen():
    img = background()
    draw = ImageDraw.Draw(img, "RGBA")
    header(draw, "写下此刻", "不用解释，也不用整理。先把这一束光轻轻放下。", "CAPTURE LIGHT")
    draw_hero_card(draw)
    card(draw, (22, 360, 368, 694))
    draw.text((42, 392), "把这一瞬间放在这里", font=F["h2"], fill=COLORS["ink"])
    draw.ellipse((306, 384, 346, 424), fill=COLORS["green"])
    draw.text((318, 394), "图", font=F["h3"], fill=(255, 255, 255))
    draw.rounded_rectangle((42, 440, 348, 544), radius=8, fill=COLORS["paper"], outline=COLORS["line"])
    draw_text(draw, (56, 458), "今天发生了什么？可以只写一句，也可以什么都不解释。", F["body"], COLORS["muted"], 270)
    x = 42
    for i, label in enumerate(["松了一口气", "有点累", "被安放", "+ 标签"]):
        x = chip(draw, x, 560, label, selected=i == 0)
    draw.rounded_rectangle((42, 607, 348, 660), radius=8, fill=COLORS["ink"])
    draw.text((135, 625), "保存这一束光", font=F["h3"], fill=(255, 255, 255))
    draw.text((22, 716), "刚刚留下的光", font=F["h2"], fill=COLORS["ink"])
    nav(draw, 0)
    img.save(OUT / "01_capture_readable.png")


def timeline_screen():
    img = background()
    draw = ImageDraw.Draw(img, "RGBA")
    header(draw, "时间线", "这些碎片不用被整理成答案，它们先按时间流动。", "TIME RIVER")
    x = 22
    for i, label in enumerate(["全部", "雨天", "灵感", "奶茶", "失眠"]):
        x = chip(draw, x, 128, label, selected=i == 0)
    draw.ellipse((22, 190, 30, 198), fill=COLORS["green"])
    draw.text((38, 184), "今天 · 2 束光", font=F["h3"], fill=COLORS["ink"])
    fragment_card(draw, 216, COLORS["blue"], "雨声把窗台变得很近", "本来只是想睡前看一眼窗外，结果突然觉得今天没有那么糟。", ["松了一口气", "雨天", "失眠"])
    fragment_card(draw, 370, COLORS["green"], "一杯青提茶", "冰块、杯壁上的水珠、路边很亮的橱窗。好像被小小地接住了一下。", ["被安放", "通勤", "奶茶"], "18:16")
    draw.ellipse((22, 552, 30, 560), fill=COLORS["green"])
    draw.text((38, 546), "昨天 · 1 束光", font=F["h3"], fill=COLORS["ink"])
    fragment_card(draw, 580, COLORS["coral"], "凌晨突然想到的片名", "如果把这段时间剪成一支短片，名字也许叫：慢慢亮起来的房间。", ["有一点期待", "灵感", "种子"], "01:22")
    nav(draw, 1)
    img.save(OUT / "02_timeline_readable.png")


def universe_screen():
    img = background()
    draw = ImageDraw.Draw(img, "RGBA")
    header(draw, "小宇宙", "标签、情绪和旧光慢慢连成一张只属于你的星图。", "PRIVATE SKY")
    sky = (22, 144, 368, 430)
    draw.rounded_rectangle(sky, radius=8, fill=(44, 79, 74))
    points = [(84, 244), (166, 196), (266, 236), (144, 320), (282, 344)]
    for a, b in zip(points, points[1:]):
        draw.line((a, b), fill=(255, 255, 255, 70), width=1)
    for i, p in enumerate(points):
        r = 18 + i * 2
        draw.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=(255, 255, 255, 45))
        draw.ellipse((p[0] - 5, p[1] - 5, p[0] + 5, p[1] + 5), fill=(255, 255, 255, 230))
    draw.text((42, 164), "近期星图", font=F["inverse"], fill=(255, 255, 255))
    draw_text(draw, (42, 366), "AI 发现：3 束光里，雨天、通勤和被安放的情绪正在靠近。", F["body"], (255, 255, 255), 220)
    draw.rounded_rectangle((283, 366, 348, 406), radius=8, fill=(255, 252, 246))
    draw.text((293, 378), "柔光整理", font=F["small"], fill=COLORS["ink"])
    draw.text((22, 456), "正在生长的主题", font=F["h2"], fill=COLORS["ink"])
    topics = [("失眠微光", "5 条记录", COLORS["blue"]), ("通勤小岛", "3 条记录", COLORS["green"]), ("创作种子", "4 条记录", COLORS["coral"]), ("雨天回声", "2 条记录", COLORS["lilac"])]
    for idx, (title, count, color) in enumerate(topics):
        x = 22 + (idx % 2) * 174
        y = 488 + (idx // 2) * 112
        card(draw, (x, y, x + 160, y + 96))
        draw.ellipse((x + 18, y + 18, x + 54, y + 54), fill=color)
        draw.text((x + 70, y + 20), title, font=F["h3"], fill=COLORS["ink"])
        draw.text((x + 70, y + 48), count + "正在靠近", font=F["small"], fill=COLORS["muted"])
    card(draw, (22, 710, 368, 742))
    draw.text((42, 718), "AI 星图管理员：只整理，不解释你。", font=F["small"], fill=COLORS["ink"])
    nav(draw, 2)
    img.save(OUT / "03_universe_readable.png")


def main() -> None:
    OUT.mkdir(exist_ok=True)
    capture_screen()
    timeline_screen()
    universe_screen()
    print(f"Generated previews in {OUT}")


if __name__ == "__main__":
    main()
