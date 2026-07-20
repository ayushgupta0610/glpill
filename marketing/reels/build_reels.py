#!/usr/bin/env python3
"""
GLPill reel builder — repeatable pipeline (committed so we never lose it again).

Every reel = 3 beats, 1080x1920, ~9.5s, silent (add trending audio in-app):
  1. HOOK   — emotional/informational line over aesthetic B-roll (fixes "bland")
  2. APP    — a real app screenshot on the brand gradient + caption (fixes "no app")
  3. ENDCARD— the twist: "Every GLP-1 app wants your data. This one can't see it."

Copy is canonical in ../MESSAGING.md. Local ffmpeg has no drawtext/libass, so all
text is rendered with PIL onto PNG layers, then animated + assembled with ffmpeg.

Usage:
  python3 build_reels.py            # build all 14
  python3 build_reels.py day2-food-noise wk3-premium-protein   # build a subset
"""
import os, sys, subprocess, tempfile
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BROLL = os.path.join(HERE, "broll")
SHOTS = os.path.join(ROOT, "docs", "screenshots")
ICON = os.path.join(ROOT, "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
OUT = HERE  # final mp4s land next to the old ones

W, H = 1080, 1920
FPS = 30
# Brand gradient (sampled from endcard.png): TL dark teal -> BR light mint
TL, BR = (15, 125, 123), (105, 198, 170)
WHITE = (255, 255, 255)

# --- fonts (resolve a real bold/semibold that PIL renders cleanly) ---
def _font(paths, size):
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()

def font_bold(size):
    return _font([
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/SFNS.ttf",
    ], size)

def font_reg(size):
    return _font([
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ], size)

# --- gradient background ---
def gradient_bg():
    base = Image.new("RGB", (W, H))
    px = base.load()
    for y in range(H):
        for x in range(W):
            t = (x / W + y / H) / 2.0
            px[x, y] = tuple(int(TL[i] + (BR[i] - TL[i]) * t) for i in range(3))
    return base

_GRAD = None
def grad():
    global _GRAD
    if _GRAD is None:
        _GRAD = gradient_bg()
    return _GRAD.copy()

def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0], size[1]], radius, fill=255)
    return m

def wrap(draw, text, font, max_w):
    """Wrap on explicit \n first, then greedily on width."""
    lines = []
    for para in text.split("\n"):
        words, cur = para.split(" "), ""
        for w in words:
            trial = (cur + " " + w).strip()
            if draw.textlength(trial, font=font) <= max_w:
                cur = trial
            else:
                if cur:
                    lines.append(cur)
                cur = w
        lines.append(cur)
    return lines

def draw_centered(draw, lines, font, cx, top, fill, line_gap=1.28, shadow=None):
    asc, desc = font.getmetrics()
    lh = int((asc + desc) * line_gap)
    y = top
    for ln in lines:
        w = draw.textlength(ln, font=font)
        x = cx - w / 2
        if shadow:
            off, col = shadow
            draw.text((x + off, y + off), ln, font=font, fill=col)
        draw.text((x, y), ln, font=font, fill=fill)
        y += lh
    return y

# --- beat 1: hook over B-roll ---
def hook_png(broll_name, text, out):
    img = Image.open(os.path.join(BROLL, broll_name)).convert("RGB")
    # cover-crop to 1080x1920
    scale = max(W / img.width, H / img.height)
    img = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
    left = (img.width - W) // 2
    top = (img.height - H) // 2
    img = img.crop((left, top, left + W, top + H))
    # bottom scrim for legibility
    scrim = Image.new("L", (W, H), 0)
    sp = scrim.load()
    for y in range(H):
        a = 0 if y < H * 0.45 else int(210 * ((y - H * 0.45) / (H * 0.55)))
        for x in range(W):
            sp[x, y] = a
    dark = Image.new("RGB", (W, H), (8, 30, 28))
    img = Image.composite(dark, img, scrim)
    d = ImageDraw.Draw(img)
    f = font_bold(76)
    lines = wrap(d, text, f, int(W * 0.86))
    asc, desc = f.getmetrics()
    lh = int((asc + desc) * 1.28)
    block_h = lh * len(lines)
    draw_centered(d, lines, f, W // 2, int(H * 0.70) - block_h // 2, WHITE,
                  shadow=(3, (0, 0, 0, 180)))
    img.save(out)

# --- beat 2: app screenshot + caption on gradient ---
def app_png(shot_name, caption, out):
    bg = grad()
    shot = Image.open(os.path.join(SHOTS, shot_name)).convert("RGB")
    target_h = 1260
    scale = target_h / shot.height
    sw, sh = int(shot.width * scale), target_h
    shot = shot.resize((sw, sh), Image.LANCZOS)
    card = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    card.paste(shot, (0, 0))
    card.putalpha(rounded_mask((sw, sh), 46))
    # drop shadow
    sh_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = (W - sw) // 2
    py = 470
    shadow = Image.new("RGBA", (sw + 80, sh + 80), (0, 0, 0, 0))
    srect = Image.new("RGBA", (sw, sh), (0, 20, 18, 130))
    srect.putalpha(rounded_mask((sw, sh), 46).point(lambda a: int(a * 0.5)))
    shadow.paste(srect, (40, 52), srect)
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    sh_img.paste(shadow, (px - 40, py - 40), shadow)
    bg = Image.alpha_composite(bg.convert("RGBA"), sh_img)
    bg.alpha_composite(card, (px, py))
    d = ImageDraw.Draw(bg)
    f = font_bold(62)
    lines = wrap(d, caption, f, int(W * 0.86))
    draw_centered(d, lines, f, W // 2, 300, WHITE, shadow=(2, (10, 60, 55, 160)))
    bg.convert("RGB").save(out)

# --- beat 3: twist endcard ---
def endcard_png(out):
    bg = grad().convert("RGBA")
    d = ImageDraw.Draw(bg)
    # app icon
    ic = Image.open(ICON).convert("RGBA").resize((248, 248), Image.LANCZOS)
    ic.putalpha(Image.composite(ic.getchannel("A"), rounded_mask((248, 248), 56), rounded_mask((248, 248), 56)))
    bg.alpha_composite(ic, ((W - 248) // 2, 560))
    fbig = font_bold(74)
    fsub = font_reg(46)
    fsmall = font_reg(40)
    y = 880
    y = draw_centered(d, wrap(d, "Every GLP-1 app wants your data.", fbig, int(W * 0.9)),
                      fbig, W // 2, y, WHITE, shadow=(2, (10, 60, 55, 150)))
    y = draw_centered(d, ["This one can't see it."], fbig, W // 2, y + 6, (223, 255, 246),
                      shadow=(2, (10, 60, 55, 150)))
    draw_centered(d, wrap(d, "Private · pill-native · Foundayo & Rybelsus", fsub, int(W * 0.9)),
                  fsub, W // 2, y + 44, (233, 250, 245))
    draw_centered(d, ["glpillapp.com  ·  @glpillapp"], fsmall, W // 2, y + 122, (210, 240, 232))
    bg.convert("RGB").save(out)

# --- ffmpeg helpers ---
def _run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

def kenburns(png, dur, out, zoom_in=True):
    if zoom_in:
        z = "min(1.001+0.00060*on,1.10)"
    else:
        z = "max(1.10-0.00060*on,1.001)"
    vf = (f"scale=3240:5760,zoompan=z='{z}':d=1:"
          f"x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s={W}x{H}:fps={FPS},setsar=1")
    _run(["ffmpeg", "-y", "-loop", "1", "-i", png, "-t", f"{dur}",
          "-vf", vf, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", str(FPS), out])

def assemble(a, b, c, durs, out):
    xf = 0.5
    off1 = durs[0] - xf
    off2 = durs[0] + durs[1] - 2 * xf
    fc = (f"[0][1]xfade=transition=fade:duration={xf}:offset={off1}[ab];"
          f"[ab][2]xfade=transition=fade:duration={xf}:offset={off2}[v]")
    _run(["ffmpeg", "-y", "-i", a, "-i", b, "-i", c,
          "-filter_complex", fc, "-map", "[v]",
          "-c:v", "libx264", "-pix_fmt", "yuv420p", "-r", str(FPS), out])

# --- reel specs (canonical copy in ../MESSAGING.md) ---
REELS = [
    ("day1-dose-demo", "still-pill-water.jpg", "Your whole GLP-1 pill routine —\nin 4 seconds.", "04-today-after-dose.png", "Tap once. Streak alive."),
    ("day2-food-noise", "still-breakfast.jpg", "Nobody warns you about the quiet.\nOne morning the food noise just… stops.", "04-today-after-dose.png", "The calm — tracked daily."),
    ("day3-app-tour", "still-hand-pill.jpg", "Every GLP-1 app was built for the needle.\nThis one's built for the pill.", "03-today-before-dose.png", "Your pill. Your plan."),
    ("day4-rybelsus-morning", "still-nightstand.jpg", "Rybelsus only absorbs on an empty stomach.\nMiss the 30-min window and the dose is wasted.", "04-today-after-dose.png", "It times the 30 minutes for you."),
    ("day5-different-app", "still-nightstand.jpg", "Your weight. Your doses. Your worst days.\nOn a GLP-1, that data is personal.", "07-report.png", "It never leaves your iPhone."),
    ("day6-doctor-report", "still-hand-pill.jpg", "“So… how's it been going?”\nFinally have a real answer.", "07-report.png", "One tap. Doctor-ready."),
    ("day7-nsv", "still-breakfast.jpg", "The scale is one number.\nThe wins are everywhere else.", "05-progress.png", "Track the trend, not the day."),
    ("wk2-day1-streak-breakers", "still-nightstand.jpg", "The #1 reason people quit the pill?\nThey lose the thread.", "06-history.png", "A streak worth keeping."),
    ("wk2-day2-wish-i-knew", "still-pill-water.jpg", "What I wish I knew before\nmy first GLP-1 pill.", "01-onboarding-welcome.png", "Set up in 60 seconds."),
    ("wk2-day3-food-noise", "still-breakfast.jpg", "Day 14: I walked past the donuts.\nDidn't even think about them.", "05-progress.png", "Small wins, adding up."),
    ("wk2-day4-doctor-report", "still-hand-pill.jpg", "Walk into your GLP-1 appointment\nwith the whole story.", "07-report.png", "Adherence · weight · side effects."),
    ("wk3-premium-morning-demo", "still-pill-water.jpg", "Your GLP-1 pill deserves\na real routine.", "04-today-after-dose.png", "Take it. Tap it. Done."),
    ("wk3-premium-protein", "still-breakfast.jpg", "On a GLP-1, protein is how\nyou keep the muscle.", "04-today-after-dose.png", "Track protein, not just weight."),
    ("wk3-premium-30sec-morning", "still-pill-water.jpg", "The 30-second\nGLP-1 morning.", "04-today-after-dose.png", "Pill, tap, timer, eat."),
]

DURS = (3.5, 4.0, 3.0)

def build_one(name, broll, hook, shot, caption, endcard_path):
    with tempfile.TemporaryDirectory() as tmp:
        a_png = os.path.join(tmp, "a.png"); b_png = os.path.join(tmp, "b.png")
        a_mp4 = os.path.join(tmp, "a.mp4"); b_mp4 = os.path.join(tmp, "b.mp4"); c_mp4 = os.path.join(tmp, "c.mp4")
        hook_png(broll, hook, a_png)
        app_png(shot, caption, b_png)
        kenburns(a_png, DURS[0], a_mp4, zoom_in=True)
        kenburns(b_png, DURS[1], b_mp4, zoom_in=False)
        kenburns(endcard_path, DURS[2], c_mp4, zoom_in=True)
        assemble(a_mp4, b_mp4, c_mp4, DURS, os.path.join(OUT, f"{name}.mp4"))
    print(f"  ✅ {name}.mp4")

def main():
    want = set(sys.argv[1:])
    endcard_path = os.path.join(HERE, "assets", "endcard-twist.png")
    endcard_png(endcard_path)
    print("built endcard-twist.png")
    for name, broll, hook, shot, caption in REELS:
        if want and name not in want:
            continue
        print(f"building {name}…")
        build_one(name, broll, hook, shot, caption, endcard_path)

if __name__ == "__main__":
    main()
