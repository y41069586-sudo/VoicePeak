#!/usr/bin/env python3
"""
Glowe - alle 4 Slides aus zwei KI-Fotos. Ein Befehl.

    python3 glowe_full_auto.py <akne.jpg> <clear.jpg> <out-verzeichnis>

    slide1.jpg   akne.jpg  + "this is what the scanner sees on day 0"
    slide2.jpg   clear.jpg + "this is what it's aiming for by day 14"
    slide3.png   App-Analyse Tag 14 - Kreis-Avatar aus clear.jpg (dieselbe Person)
    slide4.png   Routine Tag 14 - Produkte 1:1 aus RoutineBuilder (DermiqModels.swift)

Nur PIL + vorinstalliertes Chromium. Kein Netz, kein API-Key.
"""
import base64, io, subprocess, sys, glob, os, textwrap
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1080, 1920
FONT = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
INK, PURPLE, LILAC = "#161020", "#7C4FB0", "#9B6BD3"
PALE_A, PALE_B, MUTED = "#F5F1FC", "#EFE8FA", "#6B5F7A"

CAPTIONS = {1: "How to get your skin to go from this",
            2: "To this, in one month",
            3: "just scanned my face and got my score and then …",
            4: "it gave me my 14 day routine with skincare products perfect for my face"}


# Tag-14-Scores wie in der echten App (0-100, hoeher ist besser)
D14 = {"Overall": 87, "Texture": 84, "Redness": 88, "Pores": 82,
       "Evenness": 86, "Glow": 89, "Hydration": 85, "Blemishes": 91}

# Routine 1:1 aus RoutineBuilder - Profil: fettige Haut, Blemishes 51 (severe),
# Redness 55 (moderat). NICHT veraendern; siehe DermiqModels.swift.
AM = [("Gel cleanser, low-pH", "Mild surfactants", "CeraVe Foaming Cleanser - $"),
      ("Niacinamide serum", "Niacinamide 10%", "The Ordinary Niacinamide - $"),
      ("Oil-free gel moisturizer", "Ceramides + niacinamide + HA", "Neutrogena Hydro Boost - $"),
      ("SPF 50, mattifying fluid", "UV filters", "LRP Anthelios Oil Control - $$")]
PM = [("Gel cleanser, low-pH", "Mild surfactants", "COSRX Low pH Good Morning - $"),
      ("Retinal treatment", "Retinaldehyde 0.1%", "Geek & Gorgeous A-Game 10 - $$"),
      ("Oil-free gel moisturizer", "Ceramides + niacinamide + HA", "CeraVe PM Lotion - $")]


# ---- Slide 1 & 2: Foto + TikTok-Text ---------------------------------------

def cover_crop(path):
    im = Image.open(path).convert("RGB")
    s = max(W / im.width, H / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    left = (im.width - W) // 2
    top = int((im.height - H) * 0.15)
    return im.crop((left, top, left + W, top + H))


def caption(im, text, top_frac=0.60, boxed=False):
    """TikTok-Look: weisse Schrift, weicher dunkler Schatten darunter.

    NICHT die dicke schwarze Kontur - die liest sich wie ein CapCut-Meme.
    TikTok setzt einen weichen, versetzten Schatten; deshalb wird der Text
    zweimal gezeichnet: einmal unscharf als Schatten, einmal scharf darueber.
    """
    def wrap_balanced(txt, font, draw):
        """Bricht auf 1-3 moeglichst gleich lange Zeilen um.

        textwrap allein laesst gern ein einzelnes Wort auf der letzten Zeile
        stehen ("... on day" / "0"). Deshalb wird pro Zeilenzahl eine
        Ziel-Zeichenbreite vorgegeben und die erste Variante genommen, die
        wirklich passt."""
        for n in (1, 2, 3, 4):
            target = max(8, -(-len(txt) // n))
            cand = textwrap.wrap(txt, width=target)
            if len(cand) <= n and max(draw.textlength(l, font=font) for l in cand) <= W * 0.72:
                return cand
        return None

    d0 = ImageDraw.Draw(im)
    size = 62
    while size > 34:
        f = ImageFont.truetype(FONT, size)
        lines = wrap_balanced(text, f, d0)
        if lines:
            break
        size -= 3
    else:
        f = ImageFont.truetype(FONT, 38)
        lines = textwrap.wrap(text, width=24)
    lh = int(size * 1.30)

    im = im.convert("RGBA")
    if boxed:
        # TikTok-Caption mit halbtransparenter schwarzer Box - fuer die
        # hellen App-Screens, auf denen weisse Schrift allein absaeuft.
        box = Image.new("RGBA", im.size, (0, 0, 0, 0))
        db = ImageDraw.Draw(box)
        y = int(H * top_frac)
        pad = int(size * 0.42)
        for line in lines:
            w = db.textlength(line, font=f)
            x = (W - w) / 2
            db.rounded_rectangle(
                (x - pad, y - int(pad * 0.45), x + w + pad, y + int(size * 1.18)),
                radius=int(size * 0.34), fill=(0, 0, 0, 150))
            y += lh
        im.alpha_composite(box)
    else:
        shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ds = ImageDraw.Draw(shadow)
        y = int(H * top_frac)
        for line in lines:
            x = (W - ds.textlength(line, font=f)) / 2
            ds.text((x, y + 4), line, font=f, fill=(0, 0, 0, 120))
            y += lh
        shadow = shadow.filter(ImageFilter.GaussianBlur(7))
        im.alpha_composite(shadow)
    d = ImageDraw.Draw(im)
    y = int(H * top_frac)
    for line in lines:
        x = (W - d.textlength(line, font=f)) / 2
        d.text((x, y), line, font=f, fill=(255, 255, 255, 255))
        y += lh
    return im.convert("RGB")


def photo_slide(path, text, out):
    caption(cover_crop(path), text).save(out, quality=95)
    print("ok", out)


# ---- Slide 3: Analyse-Screen mit Kreis-Avatar ------------------------------

def avatar(path, size=560):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    side = min(w, h)
    left, top = (w - side) // 2, int((h - side) * 0.22)
    im = im.crop((left, top, left + side, top + side)).resize((size, size), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, format="JPEG", quality=92)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def analysis_html(uri):
    cells = ""
    for label, val in D14.items():
        col = PURPLE if label == "Overall" else INK
        cells += (f'<div class="cell"><div class="lbl">{label}</div>'
                  f'<div class="val" style="color:{col}">{val}</div>'
                  f'<div class="bar"><i style="width:{val}%"></i></div></div>')
    return f"""<!doctype html><meta charset="utf-8"><style>
*{{margin:0;padding:0;box-sizing:border-box;-webkit-font-smoothing:antialiased}}
html,body{{overflow:hidden;height:{H}px;background:linear-gradient(180deg,{PALE_A},{PALE_B})}}
body{{width:{W}px;height:{H}px;padding:96px 62px 0;
  font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif}}
h1{{font-size:82px;font-weight:800;color:{INK};text-align:center;letter-spacing:-1.5px}}
.sub{{font-size:37px;color:{MUTED};text-align:center;margin-top:22px}}
.toggle{{margin:52px auto 0;width:820px;height:118px;border-radius:60px;
  background:linear-gradient(90deg,#EFE6FB,#E3D5F6);display:flex;padding:9px}}
.toggle div{{flex:1;border-radius:52px;display:flex;align-items:center;
  justify-content:center;font-size:42px;font-weight:700}}
.on{{background:#fff;color:{PURPLE};box-shadow:0 4px 14px rgba(26,18,37,.08)}}
.off{{color:#4A3F5C}}
.avatar{{width:280px;height:280px;border-radius:50%;margin:44px auto -140px;
  border:9px solid #fff;box-shadow:0 0 0 5px rgba(155,107,211,.30),0 18px 44px rgba(124,79,176,.28);
  background-size:cover;background-position:center;position:relative;z-index:2}}
.card{{background:#fff;border-radius:56px;padding:190px 58px 52px;
  box-shadow:0 22px 60px rgba(26,18,37,.07)}}
.grid{{display:grid;grid-template-columns:1fr 1fr;gap:52px 60px}}
.lbl{{font-size:36px;color:{MUTED};margin-bottom:10px}}
.val{{font-size:74px;font-weight:800;letter-spacing:-2px;font-variant-numeric:tabular-nums}}
.bar{{height:15px;border-radius:8px;background:#ECECEF;margin-top:16px}}
.bar i{{display:block;height:100%;border-radius:8px;background:{LILAC}}}
.foot{{display:flex;align-items:center;gap:16px;margin-top:52px;font-size:31px;color:{MUTED}}}
.foot b{{width:38px;height:38px;border-radius:50%;background:{PURPLE};color:#fff;font-size:22px;
  display:flex;align-items:center;justify-content:center;flex:none}}
</style><body>
<h1>Your skin analysis</h1>
<div class="sub">A reading of you - with your 14-day potential.</div>
<div class="toggle"><div class="off">Now</div><div class="on">In 14 days</div></div>
<div class="avatar" style="background-image:url('{uri}')"></div>
<div class="card"><div class="grid">{cells}</div>
  <div class="foot"><b>&uarr;</b>Every score runs 0-100 - higher is always better.</div></div>
</body>"""


# ---- Slide 4: Routine aus echtem Code --------------------------------------

def routine_block(icon, title, when, steps):
    rows = ""
    for i, (p, a, e) in enumerate(steps, 1):
        rows += (f'<div class="step"><div class="num">{i}</div><div class="txt">'
                 f'<div class="t">{p}</div><div class="a">{a}</div>'
                 f'<div class="e">{e}</div></div></div>')
    return (f'<div class="card"><div class="hd"><div class="ic">{icon}</div>'
            f'<div><div class="bt">{title}</div><div class="bw">{when}</div></div>'
            f'<div class="cnt">{len(steps)} steps</div></div>{rows}</div>')


def routine_html():
    return f"""<!doctype html><meta charset="utf-8"><style>
*{{margin:0;padding:0;box-sizing:border-box;-webkit-font-smoothing:antialiased}}
html,body{{overflow:hidden;height:{H}px;background:linear-gradient(180deg,{PALE_A},{PALE_B})}}
body{{width:{W}px;height:{H}px;padding:62px 58px 0;
  font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif}}
.tag{{display:inline-block;background:#E7DBF8;color:#5B3A8C;font-size:30px;
  font-weight:800;letter-spacing:4px;padding:14px 30px;border-radius:36px}}
h1{{font-size:72px;font-weight:800;color:{INK};letter-spacing:-2.5px;margin-top:26px}}
.lede{{font-size:30px;color:{MUTED};margin-top:14px}}
.card{{background:#fff;border-radius:42px;padding:32px 36px;margin-top:30px;
  box-shadow:0 18px 50px rgba(26,18,37,.06)}}
.hd{{display:flex;align-items:center;gap:20px;margin-bottom:14px}}
.ic{{width:68px;height:68px;border-radius:22px;background:#EDE4FA;display:flex;
  align-items:center;justify-content:center;font-size:33px;flex:none}}
.bt{{font-size:39px;font-weight:800;color:{INK}}}
.bw{{font-size:25px;color:{MUTED};margin-top:4px}}
.cnt{{margin-left:auto;font-size:28px;font-weight:700;color:#8A7F99}}
.step{{display:flex;align-items:flex-start;gap:20px;padding:18px 0;border-top:2px solid #F2EFF7}}
.num{{width:46px;height:46px;border-radius:50%;background:#EDE4FA;color:{PURPLE};display:flex;
  align-items:center;justify-content:center;font-size:25px;font-weight:800;flex:none;margin-top:3px}}
.t{{font-size:36px;font-weight:800;color:{INK};line-height:1.14}}
.a{{font-size:26px;color:{PURPLE};font-weight:700;margin-top:6px}}
.e{{font-size:24px;color:{MUTED};margin-top:5px;font-family:ui-monospace,Menlo,monospace}}
.foot{{font-size:27px;color:{MUTED};text-align:center;margin-top:28px}}
</style><body>
<div class="tag">DAY 14</div>
<h1>my full routine</h1>
<div class="lede">built from the 8 scores - not a generic list.</div>
{routine_block("&#9728;", "Morning", "after you wake up - 8:00", AM)}
{routine_block("&#127769;", "Evening", "before bed - 22:00", PM)}
<div class="foot">retinal is evening-only - SPF every single morning</div>
</body>"""


def render(html, out):
    """+200px rendern, dann auf 1080x1920 zuschneiden - Chromium laesst sonst
    unten einen weissen Streifen (Viewport != window-size)."""
    tmp = out.replace(".png", ".html")
    open(tmp, "w").write(html)
    chrome = glob.glob("/opt/pw-browsers/chromium-*/chrome-linux/chrome")[0]
    subprocess.run([chrome, "--headless=new", "--disable-gpu", "--no-sandbox",
                    "--hide-scrollbars", "--force-device-scale-factor=1",
                    f"--window-size={W},{H + 200}", f"--screenshot={out}",
                    f"file://{os.path.abspath(tmp)}"], capture_output=True)
    os.remove(tmp)
    Image.open(out).crop((0, 0, W, H)).save(out)
    print("ok", out)


if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit("Aufruf: python3 glowe_full_auto.py <akne.jpg> <clear.jpg> <out-dir>")
    acne, clear, out = sys.argv[1], sys.argv[2], sys.argv[3]
    os.makedirs(out, exist_ok=True)
    photo_slide(acne,  CAPTIONS[1], f"{out}/slide1.jpg")
    photo_slide(clear, CAPTIONS[2], f"{out}/slide2.jpg")
    render(analysis_html(avatar(clear)), f"{out}/slide3.png")   # Gesicht = clear
    render(routine_html(),               f"{out}/slide4.png")
    # TikTok-Text auch auf den App-Screens - gleicher Look und gleiche
    # Position wie auf den Fotos, damit der Text beim Swipen stehen bleibt.
    for n, tf in ((3, 0.60), (4, 0.515)):
        p = f"{out}/slide{n}.png"
        caption(Image.open(p).convert("RGB"), CAPTIONS[n], top_frac=tf, boxed=True).save(p)
        print("ok caption", p)
    print("Fertig - 4 Slides in " + out)
