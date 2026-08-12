#!/usr/bin/env python3
# ============================================================================
#  SKINFIX — TIKTOK-SLIDESHOW.  AUFTRAG + WERKZEUG IN EINER DATEI.
# ============================================================================
#
#  An die neue Session: lies diesen Block, arbeite ihn ab, frag nicht
#  zwischendurch nach. Die zwei Bild-Prompts stehen weiter unten als
#  PROMPT_ACNE und PROMPT_CLEAR — nimm sie WÖRTLICH, nicht umformuliert.
#
#  ── SCHRITT 1 ── Foto "vorher"
#     OpenAI, Modell gpt-image-1, size 1024x1536, quality "medium".
#     NICHT "high" — das läuft bei 60 s in den Zapier-Timeout.
#     Prompt = PROMPT_ACNE (siehe unten).      →  speichern als akne.jpg
#
#  ── SCHRITT 2 ── Foto "nachher", dieselbe Frau
#     Gleiche Settings.
#     Prompt = PROMPT_CLEAR (siehe unten).     →  speichern als clear.jpg
#
#  ── SCHRITT 3 ── alle 4 Slides bauen, EIN Befehl:
#
#         python3 glowe_slideshow.py akne.jpg clear.jpg slides
#
#     slides/slide1.jpg   akne.jpg  + "How I got my skin to go from this"
#     slides/slide2.jpg   clear.jpg + "to this, in one month"
#     slides/slide3.png   SkinFix Skin-Analyse Tag 14 — der Kreis-Avatar im
#                         Chart wird automatisch aus clear.jpg geschnitten,
#                         also dieselbe Person wie auf Slide 1 und 2
#     slides/slide4.png   SkinFix Routine Tag 14
#
#     Text-Overlay, 9:16-Cover-Crop und Avatar macht das Script selbst.
#     Nichts von Hand nachbauen. Braucht nur PIL + das vorinstallierte
#     Chromium — kein Netz, kein API-Key.
#
#  ── SCHRITT 4 ── posten
#     Die 4 Bilder per Zapier an Buffer, TikTok-Slideshow, Reihenfolge
#     1-2-3-4. Caption + Hashtags vorschlagen.
#     WICHTIG: AI-Content-Label setzen. Die zwei Gesichter sind
#     KI-generiert; TikTok verlangt die Kennzeichnung bei fotorealistischen
#     generierten Personen, und ohne Label ist es in Deutschland
#     irreführende Werbung nach UWG. Der Vorher/Nachher-Hook funktioniert
#     mit Label genauso gut.
#
#  ── KONTEXT ──
#     SkinFix, iOS-Skincare-App, Bundle com.verite.com, App-Store-ID
#     6787454842. Scannt die Haut, gibt 8 Scores (0–100, höher = besser)
#     und einen 14-Tage-Plan. Farbwelt: Lila #7C4FB0 / #9B6BD3 auf hellem
#     Flieder-Verlauf.
# ============================================================================

import base64, io, subprocess, sys, glob, os, textwrap
from PIL import Image, ImageDraw, ImageFont


# ============================================================
# MARK: — Die zwei Bild-Prompts (wörtlich verwenden)
# ============================================================

# Der Extreme-Close-up-Crop ist der eigentliche Trick an diesem Paar: bei
# einem Ausschnitt aus Wange + Kieferlinie ist kaum Identität im Bild, also
# fällt es nicht auf, dass gpt-image-1 zweimal unabhängig generiert und
# dabei nicht exakt dieselbe Person trifft. Bei Halbporträts (früherer
# Versuch) war der Unterschied sofort sichtbar.
PROMPT_ACNE = """Extreme close-up of one cheek and jawline, head slightly \
tilted, only part of the face visible. Casual iPhone front-camera selfie, \
bathroom lighting, realistic skin texture with visible pores, moderate \
inflammatory acne with red pimples, papules and post-acne marks across the \
cheek and jawline, uneven skin tone, no makeup, no retouching, no perfect \
skin, authentic smartphone photo, handheld, candid TikTok slideshow aesthetic, \
impossible to distinguish from a real human photo."""

PROMPT_CLEAR = """Extreme close-up of one cheek and jawline, head slightly \
tilted, only part of the face visible. Casual iPhone front-camera selfie, \
spontaneous handheld shot, natural indoor lighting. Naturally healed skin with \
a healthy hydrated glass-skin glow while preserving realistic pores and subtle \
skin texture. No acne, no redness, no makeup, no retouching, no beauty filter, \
not perfect or plastic-looking.

Realistic smartphone camera imperfections including slight sensor noise, \
natural exposure, realistic white balance and slightly imperfect framing. \
Authentic candid TikTok skincare transformation aesthetic. Looks exactly like \
a real person took this on an iPhone. Impossible to distinguish from a genuine \
smartphone photo. No AI look, no CGI, no studio lighting, no cinematic \
lighting, no HDR, no beauty filter."""


# ============================================================
# MARK: — Konstanten
# ============================================================

W, H = 1080, 1920

# Liberation Sans Bold ist der Helvetica-Klon — am nächsten an dem, was
# TikTok für seine Text-Overlays benutzt.
FONT_PATH = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"

CAPTIONS = {
    1: "How I got my skin to go from this",
    2: "to this",
}

# Score-Sätze wie in der echten App (0–100, höher ist besser)
SCORES = {
    0:  {"Overall": 54, "Texture": 57, "Redness": 55, "Pores": 59,
         "Evenness": 56, "Glow": 51, "Hydration": 50, "Blemishes": 51},
    14: {"Overall": 87, "Texture": 84, "Redness": 88, "Pores": 82,
         "Evenness": 86, "Glow": 89, "Hydration": 85, "Blemishes": 91},
}


# ============================================================
# MARK: — Slide 1 & 2: Foto + TikTok-Text
# ============================================================

def cover_crop(path, w=W, h=H):
    """Füllt 9:16 komplett aus, ohne zu verzerren — schneidet den Überstand ab.
    Der Crop sitzt oben (0.15 statt 0.5), damit der Kopf nicht abgeschnitten
    wird, wenn das Quellbild querformatiger ist als 9:16."""
    im = Image.open(path).convert("RGB")
    scale = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    left = (im.width - w) // 2
    top = int((im.height - h) * 0.15)
    return im.crop((left, top, left + w, top + h))


def draw_caption(im, text, top_frac=0.11):
    """TikTok-Overlay: weiß, schwarze Kontur, zentriert, gewrappt.

    Die Schriftgröße wird an der längsten Zeile ausgerichtet statt fest
    gesetzt — sonst läuft "How I got my skin to go from this" aus dem Rahmen,
    während "to this, in one month" verloren klein wirkt."""
    d = ImageDraw.Draw(im)
    size, lines = 96, []
    while size > 40:
        f = ImageFont.truetype(FONT_PATH, size)
        lines = textwrap.wrap(text, width=max(12, int(W * 0.86 / (size * 0.52))))
        widest = max(d.textlength(l, font=f) for l in lines)
        if widest <= W * 0.86 and len(lines) <= 3:
            break
        size -= 4
    f = ImageFont.truetype(FONT_PATH, size)

    lh = int(size * 1.22)
    y = int(H * top_frac)
    for line in lines:
        x = (W - d.textlength(line, font=f)) / 2
        d.text((x, y), line, font=f, fill="white",
               stroke_width=max(5, size // 16), stroke_fill=(0, 0, 0))
        y += lh
    return im


def photo_slide(path, caption, out):
    im = draw_caption(cover_crop(path), caption)
    im.save(out, quality=95)
    print("✓", out)


# ============================================================
# MARK: — Slide 3 & 4: echte SkinFix-Screens
# ============================================================

def circle_avatar(path, size=560):
    """Quadratischer Gesichts-Crop, oberes Drittel gewichtet (da sitzt das Gesicht)."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    side = min(w, h)
    left = (w - side) // 2
    top = int((h - side) * 0.22)          # etwas oberhalb der Mitte = Gesicht
    im = im.crop((left, top, left + side, top + side)).resize((size, size), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, format="JPEG", quality=92)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def analysis_html(avatar_uri, day):
    s = SCORES[day]
    now_active = day == 0
    cells = ""
    for label, val in s.items():
        accent = "color:#7C4FB0" if label == "Overall" else "color:#1A1225"
        cells += f"""
        <div class="cell">
          <div class="lbl">{label}</div>
          <div class="val" style="{accent}">{val}</div>
          <div class="bar"><i style="width:{val}%"></i></div>
        </div>"""
    return f"""<!doctype html><meta charset="utf-8"><style>
*{{margin:0;padding:0;box-sizing:border-box;-webkit-font-smoothing:antialiased}}
body{{width:{W}px;height:{H}px;font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;
  background:linear-gradient(180deg,#F5F1FC 0%,#EFE8FA 100%);padding:96px 62px 0;overflow:hidden;
  position:relative}}
h1{{font-size:82px;font-weight:800;color:#161020;text-align:center;letter-spacing:-1.5px}}
.sub{{font-size:37px;color:#6B5F7A;text-align:center;margin-top:22px}}
.toggle{{margin:52px auto 0;width:820px;height:118px;border-radius:60px;
  background:linear-gradient(90deg,#EFE6FB,#E3D5F6);display:flex;padding:9px}}
.toggle div{{flex:1;border-radius:52px;display:flex;align-items:center;justify-content:center;
  font-size:42px;font-weight:700}}
.on{{background:#fff;color:#7C4FB0;box-shadow:0 4px 14px rgba(26,18,37,.08)}}
.off{{color:#4A3F5C}}
.avatar{{width:280px;height:280px;border-radius:50%;margin:44px auto -140px;
  border:9px solid #fff;box-shadow:0 0 0 5px rgba(155,107,211,.30),0 18px 44px rgba(124,79,176,.28);
  background-size:cover;background-position:center;position:relative;z-index:2}}
.card{{background:#fff;border-radius:56px;padding:190px 58px 52px;
  box-shadow:0 22px 60px rgba(26,18,37,.07)}}
.grid{{display:grid;grid-template-columns:1fr 1fr;gap:52px 60px}}
.lbl{{font-size:36px;color:#6B5F7A;margin-bottom:10px}}
.val{{font-size:74px;font-weight:800;letter-spacing:-2px;font-variant-numeric:tabular-nums}}
.bar{{height:15px;border-radius:8px;background:#ECECEF;margin-top:16px}}
.bar i{{display:block;height:100%;border-radius:8px;background:#9B6BD3}}
.foot{{display:flex;align-items:center;gap:16px;margin-top:52px;font-size:31px;color:#6B5F7A}}
.foot b{{width:38px;height:38px;border-radius:50%;background:#7C4FB0;color:#fff;font-size:22px;
  display:flex;align-items:center;justify-content:center;flex:none}}
</style><body>
<h1>Your skin analysis</h1>
<div class="sub">A reading of you — with your 14-day potential.</div>
<div class="toggle">
  <div class="{'on' if now_active else 'off'}">Now</div>
  <div class="{'off' if now_active else 'on'}">In 14 days</div>
</div>
<div class="avatar" style="background-image:url('{avatar_uri}')"></div>
<div class="card"><div class="grid">{cells}</div>
  <div class="foot"><b>↑</b>Every score runs 0–100 — higher is always better.</div>
</div>
</body>"""


def routine_html(day):
    """Routine-Screen. Tag 1 = Eingewöhnung, Tag 14 = Wirkstoffe laufen."""
    if day == 0:
        title, note = "Day 1", ("Settling in",
            "Barrier first — cleanse, moisturise, SPF. Actives start day 4.")
        steps = [("Gel cleanser, low-pH", "8:00", "Mild surfactants…"),
                 ("Oil-free gel moisturizer", "8:01", "Ceramides + niaci…"),
                 ("SPF 50, mattifying fluid", "8:03", "UV filters")]
        done = 0
    else:
        title, note = "Day 14", ("Full routine",
            "Actives are running. Rescan today to see your new score.")
        steps = [("Gel cleanser, low-pH", "8:00", "Mild surfactants…"),
                 ("Azelaic acid 10%", "8:02", "On the cheek clus…"),
                 ("SPF 50, mattifying fluid", "8:04", "UV filters")]
        done = 3
    chips = "".join(
        f'<div class="chip{" sel" if (i == (1 if day == 0 else 7)) else ""}">{i}</div>'
        for i in range(1, 8))
    rows = ""
    for i, (t, tm, d) in enumerate(steps, 1):
        check = "✓" if done else ""
        fill = "background:#7C4FB0;border-color:#7C4FB0;color:#fff" if done else ""
        rows += f"""
      <div class="step">
        <div class="check" style="{fill}">{check}</div>
        <div class="num">{i}</div>
        <div class="txt"><div class="t">{t}</div>
          <div class="d">{tm} · <span>{d}</span></div></div>
        <div class="chev">⌄</div>
      </div>"""
    return f"""<!doctype html><meta charset="utf-8"><style>
*{{margin:0;padding:0;box-sizing:border-box;-webkit-font-smoothing:antialiased}}
body{{width:{W}px;height:{H}px;font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;
  background:linear-gradient(180deg,#F7F4FD 0%,#F1EBFA 100%);padding:104px 62px 0;overflow:hidden;
  position:relative}}
h1{{font-size:104px;font-weight:800;color:#161020;letter-spacing:-2.5px}}
h1 span{{font-size:58px;color:#8A7F99;font-weight:700}}
.note{{background:#EDE4FA;border-radius:40px;padding:40px 44px;margin-top:44px;display:flex;gap:28px}}
.leaf{{font-size:44px;flex:none}}
.note .t{{font-size:42px;font-weight:800;color:#161020;margin-bottom:12px}}
.note .d{{font-size:36px;color:#4A3F5C;line-height:1.45}}
.prog{{height:16px;border-radius:8px;background:#E4E0EA;margin:52px 0 28px}}
.cnt{{font-size:36px;color:#4A3F5C;margin-bottom:44px}}
.chips{{display:flex;gap:22px;margin-bottom:52px}}
.chip{{width:118px;height:118px;border-radius:34px;background:#fff;display:flex;align-items:center;
  justify-content:center;font-size:52px;font-weight:700;color:#161020;
  box-shadow:0 4px 12px rgba(26,18,37,.05)}}
.chip.sel{{background:#E7DBF8;border:5px solid #9B6BD3;color:#5B3A8C}}
.card{{background:#fff;border-radius:52px;padding:46px 44px;box-shadow:0 18px 50px rgba(26,18,37,.06)}}
.hd{{display:flex;align-items:center;gap:28px;margin-bottom:40px}}
.sun{{width:92px;height:92px;border-radius:28px;background:#EDE4FA;display:flex;align-items:center;
  justify-content:center;font-size:44px}}
.hd .t{{font-size:50px;font-weight:800;color:#161020}}
.hd .d{{font-size:32px;color:#6B5F7A;margin-top:6px}}
.hd .c{{margin-left:auto;font-size:44px;font-weight:700;color:#8A7F99}}
.step{{display:flex;align-items:center;gap:26px;padding:30px 0;border-top:2px solid #F0EDF5}}
.check{{width:62px;height:62px;border-radius:50%;border:4px solid #D8D3E0;flex:none;
  display:flex;align-items:center;justify-content:center;font-size:34px;font-weight:800}}
.num{{width:58px;height:58px;border-radius:50%;background:#EDE4FA;color:#7C4FB0;flex:none;
  display:flex;align-items:center;justify-content:center;font-size:32px;font-weight:800}}
.txt{{flex:1}}
.txt .t{{font-size:47px;font-weight:800;color:#161020;line-height:1.15}}
.txt .d{{font-size:31px;color:#6B5F7A;margin-top:10px;font-family:ui-monospace,Menlo,monospace}}
.txt .d span{{color:#7C4FB0}}
.chev{{font-size:44px;color:#9A90A8;flex:none}}
.tabs{{position:absolute;left:50%;transform:translateX(-50%);bottom:64px;background:#fff;
  border-radius:60px;padding:22px 34px;display:flex;gap:56px;box-shadow:0 16px 46px rgba(26,18,37,.13)}}
.tab{{display:flex;flex-direction:column;align-items:center;gap:8px;font-size:30px;
  font-weight:700;color:#161020;padding:12px 26px;border-radius:44px}}
.tab.on{{background:#EDE4FA;color:#7C4FB0}}
.tab i{{font-size:40px;font-style:normal}}
</style><body>
<h1>{title} <span>of 14</span></h1>
<div class="note"><div class="leaf">🌿</div><div>
  <div class="t">{note[0]}</div><div class="d">{note[1]}</div></div></div>
<div class="prog"></div>
<div class="cnt">{done} of 6 steps today</div>
<div class="chips">{chips}</div>
<div class="card">
  <div class="hd"><div class="sun">☀️</div>
    <div><div class="t">Morning</div><div class="d">After you wake up · 8:00</div></div>
    <div class="c">{done}/3</div></div>
  {rows}
</div>
<div class="tabs">
  <div class="tab"><i>🏠</i>Home</div>
  <div class="tab on"><i>☑</i>Routine</div>
  <div class="tab"><i>📈</i>Progress</div>
</div>
</body>"""


def render(html, out):
    """Headless-Chromium liefert bei --window-size=W,H nur rund H-87px echtes
    Viewport und füllt den Rest des Screenshots WEISS auf — unten am Slide
    klebte dadurch ein 87px-Balken. Darum bewusst zu hoch anfordern und danach
    exakt auf W×H beschneiden, statt die 87px hart einzurechnen."""
    tmp = out.replace(".png", ".html")
    open(tmp, "w").write(html)
    chrome = glob.glob("/opt/pw-browsers/chromium-*/chrome-linux/chrome")[0]
    subprocess.run([chrome, "--headless=new", "--disable-gpu", "--no-sandbox",
                    "--hide-scrollbars", "--force-device-scale-factor=1",
                    f"--window-size={W},{H + 240}",
                    f"--screenshot={out}", f"file://{os.path.abspath(tmp)}"],
                   capture_output=True)
    os.remove(tmp)
    im = Image.open(out)
    if im.size != (W, H):
        im.crop((0, 0, W, H)).save(out)
    print("✓", out)


# ============================================================

if __name__ == "__main__":
    # Ohne Argumente: die zwei Prompts ausgeben, damit man sie direkt
    # kopieren kann, statt sie aus dem Quelltext zu fischen.
    if len(sys.argv) < 3:
        print("=" * 70)
        print("PROMPT 1 — akne.jpg\n")
        print(PROMPT_ACNE)
        print("\n" + "=" * 70)
        print("PROMPT 2 — clear.jpg\n")
        print(PROMPT_CLEAR)
        print("\n" + "=" * 70)
        print("\nDann:  python3 glowe_slideshow.py akne.jpg clear.jpg slides")
        sys.exit(0)

    acne, clear = sys.argv[1], sys.argv[2]
    out = sys.argv[3] if len(sys.argv) > 3 else "slides"
    os.makedirs(out, exist_ok=True)

    photo_slide(acne,  CAPTIONS[1], f"{out}/slide1.jpg")
    photo_slide(clear, CAPTIONS[2], f"{out}/slide2.jpg")
    # Avatar aus dem CLEAR-Foto: im Chart soll die Person mit dem Ergebnis
    # stehen, nicht die von vorher.
    render(analysis_html(circle_avatar(clear), 14), f"{out}/slide3.png")
    render(routine_html(14), f"{out}/slide4.png")
    print(f"\nFertig — 4 Slides in {out}/")
