#!/usr/bin/env python3
"""
GLPill reel builder — v2 "fast explainer" format (research-backed, 2026).

What changed vs v1 (build_reels.py):
  - ~24s, 10-14 FAST cuts (~2s each) instead of 3 slow beats
  - kinetic WORD-BY-WORD captions with keyword highlighting (sound-off legible)
  - statement hook in the first ~2s (not a slow sentence)
  - hook -> problem -> app payoff -> twist/loop structure
Silent (add trending audio in-app; cuts are ~2s so they land on the beat).

VISUAL RULES (locked 2026-07-23 — keep every reel fresh):
  - CONSISTENT STYLE: all B-roll shares one look — teal/cream palette, soft morning
    light, faceless, aesthetic, cinematic, 9:16. Never weight/scale/medication-shaming imagery.
  - FRESH IMAGES PER REEL: generate NEW Magnific B-roll for each reel (`broll:gen-<reel>-*.jpg`)
    instead of recycling the shared pack, so no reel looks like another.
  - BLEND: drop a REAL app screenshot (`app:<screen>.png`) exactly where the text names a
    feature (timer->Today, trend->Progress, doctor->Report); B-roll for emotional/lifestyle lines.
  - UNIQUE within a reel: every visual distinct (the 0.8s loop back to the hook is the only reuse).
  - "Free" is an end reassurance beat, never the hook.

Usage: python3 build_reel_v2.py <reel-name> | all
"""
import os, sys, subprocess, tempfile
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
BROLL = os.path.join(HERE, "broll")
SHOTS = os.path.join(ROOT, "docs", "screenshots")

W, H, FPS = 1080, 1920, 30
TL, BR = (15, 125, 123), (105, 198, 170)
WHITE = (255, 255, 255)
GOLD = (255, 210, 74)          # keyword highlight
REVEAL = 0.14                  # seconds per word appearing
CAP_Y = 0.81                   # caption vertical center (lower third, clears the phone)

def _font(paths, size):
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()

def font_bold(size):
    return _font(["/System/Library/Fonts/Helvetica.ttc",
                  "/System/Library/Fonts/HelveticaNeue.ttc"], size)

_GRAD = None
def grad():
    global _GRAD
    if _GRAD is None:
        g = Image.new("RGB", (W, H)); px = g.load()
        for y in range(H):
            for x in range(W):
                t = (x / W + y / H) / 2.0
                px[x, y] = tuple(int(TL[i] + (BR[i] - TL[i]) * t) for i in range(3))
        _GRAD = g
    return _GRAD.copy()

def rounded_mask(size, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0], size[1]], r, fill=255)
    return m

# ---- background stills (no text) ----
def bg_broll(name):
    img = Image.open(os.path.join(BROLL, name)).convert("RGB")
    s = max(W / img.width, H / img.height)
    img = img.resize((int(img.width * s), int(img.height * s)), Image.LANCZOS)
    l, t = (img.width - W) // 2, (img.height - H) // 2
    return img.crop((l, t, l + W, t + H))

def bg_app(name):
    bg = grad()
    shot = Image.open(os.path.join(SHOTS, name)).convert("RGB")
    th = 1100; sw = int(shot.width * th / shot.height)
    shot = shot.resize((sw, th), Image.LANCZOS)
    card = Image.new("RGBA", (sw, th), (0, 0, 0, 0)); card.paste(shot, (0, 0))
    card.putalpha(rounded_mask((sw, th), 44))
    px, py = (W - sw) // 2, 250
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    blk = Image.new("RGBA", (sw, th), (0, 20, 18, 120)); blk.putalpha(rounded_mask((sw, th), 44).point(lambda a: int(a*0.45)))
    sh.paste(blk, (px, py + 16), blk); sh = sh.filter(ImageFilter.GaussianBlur(24))
    out = Image.alpha_composite(bg.convert("RGBA"), sh)
    out.alpha_composite(card, (px, py))
    return out.convert("RGB")

def bg_endcard():
    bg = grad().convert("RGBA")
    ic = os.path.join(ROOT, "App", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
    icon = Image.open(ic).convert("RGBA").resize((230, 230), Image.LANCZOS)
    icon.putalpha(Image.composite(icon.getchannel("A"), rounded_mask((230, 230), 52), rounded_mask((230, 230), 52)))
    bg.alpha_composite(icon, ((W - 230) // 2, 470))
    d = ImageDraw.Draw(bg)
    uf = font_bold(42)
    url = "glpillapp.com  ·  @glpillapp"
    d.text(((W - d.textlength(url, font=uf)) / 2, int(H * 0.90)), url, font=uf, fill=(228, 247, 240, 255))
    return bg.convert("RGB")

# ---- kinetic caption: layout full phrase, reveal word-by-word ----
def layout(phrase, kw, font):
    """Return (positions, box) — positions = [(x,y,word,is_kw)], box=(x0,y0,x1,y1)."""
    d = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    words = phrase.split(" ")
    max_w = int(W * 0.80)
    sp = d.textlength(" ", font=font)
    asc, desc = font.getmetrics(); lh = int((asc + desc) * 1.12)
    lines, cur, curw = [], [], 0.0
    for w in words:
        ww = d.textlength(w, font=font)
        if cur and curw + sp + ww > max_w:
            lines.append(cur); cur, curw = [], 0.0
        cur.append(w); curw += (sp if len(cur) > 1 else 0) + ww
    if cur:
        lines.append(cur)
    block_h = lh * len(lines)
    cy = int(H * CAP_Y)
    top = cy - block_h // 2
    pos, gi = [], 0
    widths = [sum(d.textlength(w, font=font) for w in ln) + sp * (len(ln) - 1) for ln in lines]
    for li, ln in enumerate(lines):
        x = (W - widths[li]) / 2; y = top + li * lh
        for w in ln:
            pos.append((x, y, w, w.strip(".,—-") == kw))
            x += d.textlength(w, font=font) + sp
        gi += len(ln)
    pad = 34
    x0 = (W - max(widths)) / 2 - pad; x1 = (W + max(widths)) / 2 + pad
    box = (int(x0), int(top - pad + 6), int(x1), int(top + block_h + pad - 6))
    return pos, box

def caption_png(pos, box, font, upto, flash_last, out):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, 30, fill=(8, 22, 20, 205))
    for i, (x, y, word, is_kw) in enumerate(pos[:upto]):
        col = GOLD if (is_kw or (flash_last and i == upto - 1)) else WHITE
        d.text((x + 2, y + 2), word, font=font, fill=(0, 0, 0, 150))
        d.text((x, y), word, font=font, fill=col)
    img.save(out)

def kenburns(png, dur, out, zin=True):
    z = "min(1.0+0.0022*on,1.16)" if zin else "max(1.15-0.0020*on,1.0)"
    vf = (f"scale=3240:5760,zoompan=z='{z}':d=1:x='iw/2-(iw/zoom/2)':"
          f"y='ih/2-(ih/zoom/2)':s={W}x{H}:fps={FPS},setsar=1")
    subprocess.run(["ffmpeg","-y","-loglevel","error","-loop","1","-i",png,"-t",f"{dur}",
                    "-vf",vf,"-c:v","libx264","-pix_fmt","yuv420p","-r",str(FPS),out], check=True)

def segment(bg_img, dur, phrase, kw, tmp, idx):
    still = os.path.join(tmp, f"bg{idx}.png"); bg_img.save(still)
    bgclip = os.path.join(tmp, f"bg{idx}.mp4")
    kenburns(still, dur, bgclip, zin=(idx % 2 == 0))
    font = font_bold(70)
    pos, box = layout(phrase, kw, font)
    k = len(pos)
    R = min(REVEAL, (dur * 0.7) / max(k, 1))   # ensure the phrase finishes building in time
    caps = []  # (png, t0, t1) — building states flash the newest word gold, then a settled state holds
    for j in range(1, k + 1):
        p = os.path.join(tmp, f"cap{idx}_b{j}.png")
        caption_png(pos, box, font, j, True, p)
        caps.append((p, (j - 1) * R, j * R))
    settled = os.path.join(tmp, f"cap{idx}_s.png")
    caption_png(pos, box, font, k, False, settled)
    caps.append((settled, k * R, dur + 1))
    inputs = ["-i", bgclip]
    for c, _, _ in caps:
        inputs += ["-loop", "1", "-i", c]
    fc, last = "", "[0:v]"
    for j, (_, t0, t1) in enumerate(caps):
        fc += f"{last}[{j+1}:v]overlay=enable='between(t,{t0:.3f},{t1:.3f})'[o{j}];"
        last = f"[o{j}]"
    fc = fc.rstrip(";")
    outc = os.path.join(tmp, f"seg{idx}.mp4")
    subprocess.run(["ffmpeg","-y","-loglevel","error", *inputs,
                    "-filter_complex", fc, "-map", last, "-t", f"{dur}",
                    "-c:v","libx264","-pix_fmt","yuv420p","-r",str(FPS), outc], check=True)
    return outc

# ---- B-roll library (short keys → files in broll/) ----
B = {
    "pw": "still-pill-water.jpg", "hp": "still-hand-pill.jpg",
    "bf": "still-breakfast.jpg", "ns": "still-nightstand.jpg",
    "clock": "gen-clock.jpg", "journal": "gen-journal.jpg", "coffee": "gen-coffee.jpg",
    "protein": "gen-protein.jpg", "water": "gen-water.jpg", "walking": "gen-walking.jpg",
    "phone": "gen-phone.jpg", "bedside": "gen-bedside.jpg",
    "kitchen": "gen-kitchen.jpg", "cafe": "gen-cafe-dessert.jpg", "tea": "gen-tea.jpg",
    "calendar": "gen-calendar.jpg", "pillcase": "gen-pillcase.jpg",
}
TWIST = ("endcard", 3.6, "Every GLP-1 app wants your data. This one CAN'T see it", "CAN'T")

def resolve(key):
    # "endcard" | "app:<screenshot.png>" (real app screen) | "broll:<file.jpg>" (per-reel
    # fresh B-roll) | short key into the shared B pack (legacy reels)
    if key == "endcard":
        return bg_endcard()
    if key.startswith("app:"):
        return bg_app(key[4:])
    if key.startswith("broll:"):
        return bg_broll(key[6:])
    return bg_broll(B[key])

# ---- the 14 reels: statement hook -> problem -> payoff (feature via kinetic text) ----
# Screenshot-free (all B-roll). The twist endcard + a 0.8s loop-back-to-hook are appended
# automatically. Copy stays in the twist-forward / private, pill-native voice.
REELS = {
 "day1-dose-demo": [
    ("pw",2.2,"Your GLP-1 pill routine takes 4 SECONDS","SECONDS"),
    ("hp",1.8,"No needles. No shot days.","No"),
    ("pw",2.0,"Take the pill with water","water"),
    ("coffee",1.8,"one tap, done","tap"),
    ("journal",2.0,"your streak stays alive","streak"),
    ("clock",2.0,"the timer runs itself","timer"),
    ("phone",2.0,"and your data never leaves your phone","never"),
 ],
 # day2/day3 refreshed 2026-07-22: all-unique images per beat + "free" as end reassurance
 "day2-food-noise": [
    ("bf",2.4,"Nobody warns you about the QUIET","QUIET"),
    ("kitchen",2.2,"One morning the food noise just stops","stops"),
    ("cafe",2.2,"You walk right past the dessert","past"),
    ("walking",2.0,"and don't even think about it","don't"),
    ("bedside",2.0,"Then it just feels normal","normal"),
    ("journal",2.2,"GLPill tracks the whole shift","tracks"),
    ("tea",2.0,"quietly, privately, on your phone","privately"),
    ("coffee",1.8,"and it's completely free","free"),
 ],
 "day3-app-tour": [
    ("hp",2.4,"Every GLP-1 app was built for the NEEDLE","NEEDLE"),
    ("pw",2.0,"But you take a pill","pill"),
    ("calendar",2.0,"Daily, not weekly","Daily"),
    ("water",1.8,"No injection sites","No"),
    ("clock",2.0,"just a 30-minute rule","30-minute"),
    ("pillcase",2.2,"GLPill is built for exactly that","built"),
    ("phone",2.0,"and it can't see your data","can't"),
    ("journal",1.8,"Free, private, made for the pill","Free"),
 ],
 "day4-rybelsus-morning": [
    ("pw",2.4,"You're probably WASTING your Rybelsus","WASTING"),
    ("hp",2.0,"It only works on an EMPTY stomach","EMPTY"),
    ("bf",1.8,"Eat too soon and",None),
    ("cafe",1.8,"the dose is basically GONE","GONE"),
    ("clock",2.2,"The rule: wait 30 minutes","30"),
    ("water",2.2,"GLPill times that window for you","times"),
    ("kitchen",2.2,"down to the EXACT minute you can eat","EXACT"),
    ("tea",2.0,"so you never miss it","never"),
    ("journal",1.8,"Free, private, built for the pill","Free"),
 ],
 "day5-different-app": [
    ("ns",2.4,"Your weight. Your doses. Your worst days.",None),
    ("phone",2.2,"On a GLP-1, that data is PERSONAL","PERSONAL"),
    ("walking",2.0,"You shouldn't have to hand it to a startup","startup"),
    ("journal",2.0,"Every other app wants it","wants"),
    ("pw",2.2,"GLPill literally can't see yours","can't"),
    ("bedside",2.0,"No account. No servers.","No"),
    ("phone",2.0,"It all stays on your phone","stays"),
 ],
 # day6/day7 rebuilt 2026-07-23: blended (fresh B-roll + real app screens at feature beats)
 "day6-doctor-report": [
    ("broll:gen-d6-clinic.jpg",2.4,"“So, how's it been going?”",None),
    ("broll:gen-d6-notepad.jpg",2.0,"Most people just guess","guess"),
    ("app:07-report.png",2.8,"GLPill hands over the whole story","whole"),
    ("broll:gen-d6-organizer.jpg",2.0,"Every dose, logged","logged"),
    ("app:05-progress.png",2.6,"your weight, trended","trended"),
    ("broll:gen-d6-share.jpg",2.2,"One tap to share — your call","call"),
    ("broll:gen-d6-tea.jpg",1.8,"Free, private, built for the pill","Free"),
 ],
 "day7-nsv": [
    ("broll:gen-d7-sunrise.jpg",2.4,"The scale is just ONE number","ONE"),
    ("broll:gen-d7-coffee.jpg",2.0,"The real wins are everywhere else","everywhere"),
    ("broll:gen-d7-bed.jpg",2.0,"Deeper sleep. Steadier energy.","energy"),
    ("app:05-progress.png",2.6,"GLPill tracks the trend, not the day","trend"),
    ("broll:gen-d7-walk.jpg",2.0,"and the wins a scale never sees","never"),
    ("broll:gen-d7-journal.jpg",2.0,"logged, just for you","logged"),
    ("broll:gen-d7-phone.jpg",1.8,"Free, private, on your phone","Free"),
 ],
 "wk2-day1-streak-breakers": [
    ("ns",2.4,"Most people quit the pill for ONE reason","ONE"),
    ("bedside",2.0,"They lose the thread","lose"),
    ("coffee",2.0,"One missed morning becomes three","three"),
    ("bedside",2.0,"then guilt makes them stop","guilt"),
    ("journal",2.2,"A streak keeps you honest","streak"),
    ("clock",2.0,"a nudge keeps you on time","nudge"),
    ("phone",2.0,"GLPill does both, privately","both"),
 ],
 "wk2-day2-wish-i-knew": [
    ("pw",2.4,"What I wish I knew before my first pill","wish"),
    ("hp",2.0,"The empty-stomach window is everything","everything"),
    ("protein",2.0,"Protein protects your muscle","Protein"),
    ("water",2.0,"Water kills most of the nausea","Water"),
    ("bedside",1.8,"Start low, the side effects fade","fade"),
    ("journal",2.2,"GLPill keeps all of it on track","track"),
    ("phone",2.0,"and off everyone else's servers","off"),
 ],
 "wk2-day3-food-noise": [
    ("coffee",2.4,"Day 14 on the pill",None),
    ("walking",2.2,"I walked past the office donuts","past"),
    ("bf",2.0,"Didn't even think about them","Didn't"),
    ("bedside",2.0,"My brain just got quieter","quieter"),
    ("journal",2.2,"The small wins add up fast","add"),
    ("journal",2.0,"GLPill helps you see them","see"),
    ("phone",2.0,"kept private, on your phone","private"),
 ],
 "wk2-day4-doctor-report": [
    ("journal",2.4,"Walk into your appointment PREPARED","PREPARED"),
    ("ns",2.2,"Not “uh, pretty good I think”",None),
    ("coffee",2.0,"Your doctor can actually adjust your plan","adjust"),
    ("journal",2.0,"Adherence, weight, side effects",None),
    ("journal",2.0,"GLPill hands you the whole picture","whole"),
    ("phone",2.2,"One tap to share, when you choose","choose"),
    ("pw",2.0,"Nothing leaves your phone otherwise","Nothing"),
 ],
 "wk3-premium-morning-demo": [
    ("bedside",2.4,"Your GLP-1 pill deserves a real RITUAL","RITUAL"),
    ("pw",2.0,"Take it with water, first thing","first"),
    ("coffee",2.0,"one tap to log it","tap"),
    ("clock",2.0,"the timer runs itself","timer"),
    ("water",2.0,"protein and water, tracked","tracked"),
    ("journal",2.2,"your streak grows","streak"),
    ("phone",2.0,"all private, on your phone","private"),
 ],
 "wk3-premium-protein": [
    ("protein",2.4,"On a GLP-1 you can lose MUSCLE","MUSCLE"),
    ("bf",2.0,"A small appetite makes protein hard","hard"),
    ("protein",2.0,"So lead with protein every meal","lead"),
    ("walking",2.0,"Muscle is what keeps the weight off","keeps"),
    ("water",2.0,"and keep the water coming","water"),
    ("journal",2.2,"GLPill tracks it so you don't guess","tracks"),
    ("phone",2.0,"privately, on your phone","privately"),
 ],
 "wk3-premium-30sec-morning": [
    ("bedside",2.2,"The 30-SECOND GLP-1 morning","30-SECOND"),
    ("pw",1.8,"Pill",None),
    ("coffee",1.6,"one tap","tap"),
    ("clock",1.8,"timer starts","timer"),
    ("bf",1.8,"eat when it says so","eat"),
    ("journal",2.0,"streak kept, muscle protected","streak"),
    ("phone",2.0,"and nobody sees your data","nobody"),
 ],
}

def build_reel(name, beats, out):
    # each reel should use a unique image per beat (the loop back to the hook is the only reuse)
    keys = [b[0] for b in beats]
    dupes = sorted({k for k in keys if keys.count(k) > 1})
    if dupes:
        print(f"  ⚠ {name} reuses image(s) within the reel: {', '.join(dupes)}")
    full = list(beats) + [TWIST, (beats[0][0], 0.8, beats[0][2], beats[0][3])]
    with tempfile.TemporaryDirectory() as tmp:
        segs = []
        for i, (key, dur, phrase, kw) in enumerate(full):
            segs.append(segment(resolve(key), dur, phrase, kw, tmp, i))
        lst = os.path.join(tmp, "list.txt")
        with open(lst, "w") as f:
            for s in segs:
                f.write(f"file '{s}'\n")
        subprocess.run(["ffmpeg","-y","-loglevel","error","-f","concat","-safe","0","-i",lst,
                        "-c:v","libx264","-pix_fmt","yuv420p","-r",str(FPS), out], check=True)
    d = subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",out],
                       capture_output=True, text=True).stdout.strip()
    print(f"  ✅ {name}.mp4 ({d}s)")

def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else "all"
    names = list(REELS) if arg == "all" else [arg]
    for name in names:
        print(f"building {name}…")
        build_reel(name, REELS[name], os.path.join(HERE, f"{name}.mp4"))

if __name__ == "__main__":
    main()
