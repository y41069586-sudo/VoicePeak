#!/usr/bin/env python3
"""Glowe Carousel Renderer v2 - bolder. JSON in, 5 PNG slides (1080x1440) out."""
import base64, glob, html, io, json, math, os, subprocess, sys
from PIL import Image, ImageFont

# Assets liegen neben diesem Script, nicht relativ zum Aufrufort — damit
# funktioniert `photo` in der JSON unabhaengig davon, aus welchem Verzeichnis
# gerendert wird.
ASSET_DIR = os.path.dirname(os.path.abspath(__file__))

# Poppins ist hier nicht installierbar (Google-Fonts-Host liegt hinter dem
# Proxy-Deny). Inter Display ist der naechste verfuegbare geometrische Sans
# mit echtem Bold — TeX Gyre Chorus fuer die Script-Woerter ist das Original.
FONT_SANS   = "Inter Display"
FONT_HEAVY  = "Inter Display"
FONT_SCRIPT = "TeX Gyre Chorus"

LAV   = "#B9A7E6"
DEEP  = "#3A2E55"
BODY  = "#6E6685"
GHOST = "rgba(185,167,230,0.12)"
CARD  = "#EDE6F9"

BASE_CSS = f"""
* {{ margin:0; padding:0; }}
body {{
  width:1080px; height:1440px; overflow:hidden; position:relative;
  background:-webkit-linear-gradient(top, #F5F0FB 0%, #FFFFFF 46%);
  font-family:'{FONT_SANS}';
}}
.ribbon {{ position:absolute; top:0; left:513px; }}
.ghost {{
  position:absolute; top:-60px; right:-140px;
  font-weight:700; font-size:960px; line-height:1;
  color:{GHOST};
  text-shadow: 3px 0 {GHOST}, -3px 0 {GHOST};
}}
.content {{ position:absolute; left:90px; top:300px; width:900px; }}
/* Slide 1 traegt Headline + Subline + Pill und sitzt mit dem gemeinsamen
   top:300px sichtbar zu tief. Nur diese Slide hoeher haengen — die
   Step-Slides brauchen den Platz oben fuer die Ghost-Ziffer. */
.content.high {{ top:200px; }}
.eyebrow {{
  font-weight:700; font-size:38px; letter-spacing:6px;
  color:{LAV}; text-transform:uppercase; margin-bottom:44px;
}}
.headline {{
  font-weight:700; font-size:132px; line-height:1.0;
  color:{DEEP}; letter-spacing:-2px;
  text-shadow: 1.6px 0 {DEEP}, -1.6px 0 {DEEP};
}}
.script {{
  display:block;
  font-family:'{FONT_SCRIPT}'; font-weight:normal; font-size:180px; line-height:0.9;
  color:{LAV}; letter-spacing:0; text-shadow:none; margin-bottom:6px;
}}
.bar {{ width:220px; height:12px; border-radius:6px; background:{LAV}; margin-top:48px; }}
.sub {{ font-size:47px; color:{BODY}; line-height:1.5; margin-top:54px; }}
.card {{
  background:#FFFFFF; border:3px solid {CARD}; border-radius:36px;
  padding:56px 60px; margin-top:70px; width:770px;
}}
.bullet {{ font-size:45px; color:{BODY}; line-height:1.45; }}
.bullet + .bullet {{ margin-top:36px; }}
.dot {{
  display:inline-block; width:16px; height:16px; border-radius:8px;
  background:{LAV}; margin-right:28px; vertical-align:6px;
}}
.pill {{
  display:inline-block; background:{LAV}; color:#FFFFFF;
  font-weight:700; font-size:46px; letter-spacing:3px;
  padding:30px 58px; border-radius:70px; margin-top:74px;
}}
/* Laengere CTAs ("COMMENT GLOW FOR EARLY ACCESS") sprengen bei 46px die
   900px-Spalte und brechen um. Eine Stufe kleiner haelt sie einzeilig und
   der Pill bleibt trotzdem das groesste Element der Slide. */
.pill.long {{ font-size:36px; letter-spacing:2px; padding:28px 46px; }}
.after-pill {{ font-size:44px; color:{BODY}; line-height:1.5; margin-top:40px; }}
.line2 {{ font-size:38px; color:{BODY}; line-height:1.5; margin-top:20px; }}
/* Zweiter CTA unter dem GLOW-Pill. Lavendel + bold, damit er als eigener
   Call-to-Action liest, aber kleiner bleibt als der Pill — der Kommentar
   ist der Hauptweg, Early Access der Anschluss. */
.early {{
  font-weight:700; font-size:42px; color:{LAV}; line-height:1.4; margin-top:34px;
}}
.logo {{
  position:absolute; bottom:60px; right:90px;
  font-family:'{FONT_SCRIPT}'; font-size:62px; color:{LAV};
}}
"""

RIBBON_SVG = f"""<svg class="ribbon" width="54" height="86" xmlns="http://www.w3.org/2000/svg">
<polygon points="0,0 54,0 54,86 27,64 0,86" fill="{LAV}"/></svg>"""

def page(inner, ghost=None, high=False):
    g = f'<div class="ghost">{ghost}</div>' if ghost else ""
    cls = "content high" if high else "content"
    return (f"<!DOCTYPE html><html><head><meta charset='utf-8'>"
            f"<style>{BASE_CSS}</style></head><body>{g}{RIBBON_SVG}"
            f"<div class='{cls}'>{inner}</div>"
            f"<div class='logo'>Glow&eacute;</div></body></html>")


# ── Native Hook-Slide ────────────────────────────────────────────────────────
# Slide 1 ist auf einem kalten Feed die einzige, die die meisten Leute sehen.
# Das gebrandete Cover — Ribbon, Logo, Markenfarben, Versalien — liest dort in
# Sekundenbruchteilen als Anzeige und wird weggewischt. Diese Variante hat
# keinerlei Markenzeichen: flacher, leicht warmer Hintergrund, Systemschrift,
# Kleinschreibung, linksbündig. Sieht aus wie in der TikTok-App getippt.
# Slides 2–5 bleiben gebrandet — wer wischt, hat sich schon entschieden, und
# dort ist die Marke Vertrauenssignal statt Stoppschild.

NATIVE_CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
body {{
  width:{{W}}px; height:{{H}}px; overflow:hidden; position:relative;
  background:#F7F5F2;
  font-family:'{FONT_SANS}', -apple-system, 'Helvetica Neue', sans-serif;
  -webkit-font-smoothing:antialiased;
}}
.wrap {{ position:absolute; left:82px; right:82px; top:360px; }}
.hook {{
  font-weight:700; color:#171717; line-height:1.16; letter-spacing:-1.5px;
}}
.sub {{
  font-size:44px; color:#6E6E6E; line-height:1.42; margin-top:38px;
  font-weight:400;
}}
.swipe {{
  position:absolute; left:82px; bottom:96px;
  font-size:38px; color:#A3A099; font-weight:500;
}}
"""


# ── Photo-Hook-Slide ─────────────────────────────────────────────────────────
# Die stärkste Variante: echtes Foto als Beweis, darüber ein handgezeichnet
# wirkender gestrichelter Pfeil, der auf die Haut zeigt. Das Format läuft in
# der Nische, weil es zeigt statt behauptet — und der Pfeil zwingt das Auge
# genau dorthin, wo das Versprechen sichtbar ist.

PHOTO_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
body {
  width:{W}px; height:{H}px; overflow:hidden; position:relative;
  font-family:'{FONT}', -apple-system, 'Helvetica Neue', sans-serif;
  -webkit-font-smoothing:antialiased;
}
.shot { position:absolute; inset:0; background-size:cover; background-position:center; }
/* Verlauf nur oben — die Kopfzeile braucht Kontrast, das Gesicht darunter
   soll unangetastet bleiben. */
.scrim {
  position:absolute; left:0; right:0; top:0; height:56%;
  background:linear-gradient(180deg, rgba(0,0,0,.60) 0%, rgba(0,0,0,.28) 46%, rgba(0,0,0,0) 100%);
}
.hook {
  position:absolute; left:72px; right:72px; top:132px;
  font-weight:700; color:#fff; line-height:1.12; letter-spacing:-1.5px;
  text-shadow:0 4px 26px rgba(0,0,0,.5);
}
.hook em { font-style:normal; color:{LAV}; }
.arrow { position:absolute; inset:0; }
.swipe {
  position:absolute; left:74px; bottom:210px;
  font-size:38px; font-weight:600; color:#fff; opacity:.85;
  text-shadow:0 2px 14px rgba(0,0,0,.6);
}
"""


def _photo_data_uri(path):
    """Foto auf Zielgroesse bringen und als JPEG einbetten — das Original ist
    ein 2,3-MB-PNG, als JPEG bleiben rund 250 KB, sichtbar identisch."""
    im = Image.open(path).convert("RGB")
    if im.size != (W, H):
        scale = max(W / im.width, H / im.height)
        im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
        left, top = (im.width - W) // 2, (im.height - H) // 2
        im = im.crop((left, top, left + W, top + H))
    buf = io.BytesIO()
    im.save(buf, format="JPEG", quality=90, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def build_photo_hook(slide):
    uri = _photo_data_uri(os.path.join(ASSET_DIR, slide["photo"]))
    size = fit_hook(slide["hook"], budget=520, start=96)
    # <em> im JSON faerbt einen Teil lavendel ein, ohne HTML im Text zu erlauben.
    hook = html.escape(slide["hook"]).replace("[", "<em>").replace("]", "</em>")
    a = slide.get("arrow", {})
    x0, y0 = a.get("from", [240, 840])
    cx, cy = a.get("via", [450, 880])
    x1, y1 = a.get("to", [762, 566])
    # Spitze aus der Tangente der Bezier-Kurve rechnen statt sie fest zu
    # verdrahten — sonst zeigt sie in die falsche Richtung, sobald jemand die
    # Kurve fuer ein anderes Foto verschiebt. Tangente am Ende = P_end - P_ctrl.
    dx, dy = x1 - cx, y1 - cy
    ln = math.hypot(dx, dy) or 1.0
    ux, uy = dx / ln, dy / ln
    barbs = []
    for ang in (math.radians(150), math.radians(-150)):
        bx = (ux * math.cos(ang) - uy * math.sin(ang)) * 58
        by = (ux * math.sin(ang) + uy * math.cos(ang)) * 58
        barbs.append(f"M {x1} {y1} l {bx:.1f} {by:.1f}")
    arrow = (f"<svg class='arrow' viewBox='0 0 {W} {H}'>"
             f"<path d='M {x0} {y0} Q {cx} {cy} {x1} {y1}' fill='none' stroke='{LAV}'"
             f" stroke-width='9' stroke-linecap='round' stroke-dasharray='26 22'/>"
             f"<path d='{' '.join(barbs)}' fill='none'"
             f" stroke='{LAV}' stroke-width='9' stroke-linecap='round'/></svg>")
    css = (PHOTO_CSS.replace("{W}", str(W)).replace("{H}", str(H))
           .replace("{FONT}", FONT_SANS).replace("{LAV}", "#CBB9F2"))
    return (f"<!DOCTYPE html><html><head><meta charset='utf-8'>"
            f"<style>{css}</style></head><body>"
            f"<div class='shot' style=\"background-image:url('{uri}')\"></div>"
            f"<div class='scrim'></div>"
            f"<div class='hook' style='font-size:{size}px'>{hook}</div>"
            f"{arrow}"
            f"<div class='swipe'>{html.escape(slide.get('swipe', 'swipe →'))}</div>"
            f"</body></html>")


def fit_hook(text, budget=560, start=104, floor=56):
    """Wie fit_headline, aber fuer den Fliesstext der nativen Hook-Slide:
    Kleinschreibung, kein Script-Wort, engere Spalte (916px)."""
    size = start
    while size > floor:
        font = ImageFont.truetype(SANS_BOLD, size)
        lines = _wrap(text.split(), font, -1.5, max_w=W - 164)   # 82px Rand je Seite
        if len(lines) * size * 1.16 <= budget:
            break
        size -= 4
    return size


def build_native_hook(slide):
    hook = html.escape(slide["hook"])
    size = fit_hook(slide["hook"])
    sub = f"<div class='sub'>{html.escape(slide['hook_sub'])}</div>" if slide.get("hook_sub") else ""
    swipe = html.escape(slide.get("swipe", "swipe →"))
    css = NATIVE_CSS.replace("{W}", str(W)).replace("{H}", str(H))
    return (f"<!DOCTYPE html><html><head><meta charset='utf-8'>"
            f"<style>{css}</style></head><body>"
            f"<div class='wrap'><div class='hook' style='font-size:{size}px'>{hook}</div>{sub}</div>"
            f"<div class='swipe'>{swipe}</div></body></html>")

SANS_BOLD = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
COL_W = 900          # Breite der .content-Spalte
HEAD_MAX, HEAD_MIN = 132, 68
SCRIPT_RATIO = 180 / 132   # .script haengt proportional an der Headline


def _wrap(words, font, tracking, max_w=COL_W):
    """Greedy-Umbruch wie im Browser, inkl. letter-spacing."""
    lines, cur = [], []
    for w in words:
        trial = cur + [w]
        s = " ".join(trial)
        if not cur or font.getlength(s) + tracking * len(s) <= max_w:
            cur = trial
        else:
            lines.append(cur)
            cur = [w]
    if cur:
        lines.append(cur)
    return lines


def fit_headline(text, script_word, budget):
    """Groesste Headline-Groesse, mit der der Block in `budget` Pixel passt.

    Die Headline stand vorher fix auf 132px. Bei "Calm acne without wrecking
    skin" ergibt das vier Grossbuchstaben-Zeilen, der Textblock lief unten
    raus und der Pill schob sich ueber das Glowé-Logo. Statt die Texte zu
    kuerzen wird die Groesse an der echten Schrift gemessen und passend
    heruntergestuft."""
    caps = [w for w in text.split()
            if not (script_word and w.strip("?!.,").lower() == script_word.lower())]
    size = HEAD_MAX
    while size > HEAD_MIN:
        font = ImageFont.truetype(SANS_BOLD, size)
        h = len(_wrap([w.upper() for w in caps], font, -2.0)) * size   # line-height 1.0
        if script_word:
            h += size * SCRIPT_RATIO * 0.9 + 6                          # .script + margin
        if h <= budget:
            break
        size -= 4
    return size


def headline_html(text, script_word=None, size=HEAD_MAX):
    """Nur der Inhalt — die Groesse setzt build() auf das .headline-div selbst.
    Sie darf nicht auf einen inneren span: line-height:1.0 ist unitless und
    bezieht sich auf die Schriftgroesse des Elements, das es traegt. Auf dem
    div haengend blieben die Zeilenboxen sonst auf 132px stehen, egal wie
    klein der Text darin wird."""
    words, out = text.split(), []
    for w in words:
        if script_word and w.strip("?!.,").lower() == script_word.lower():
            out.append(f"<span class='script' style='font-size:"
                       f"{round(size * SCRIPT_RATIO)}px'>{w.lower()}</span>")
        else:
            out.append(w.upper())
    return " ".join(out)

# Vertikales Budget der Headline je Slide-Typ: Spaltenhoehe bis 40px ueber
# das Logo, minus der Bloecke mit fester Hoehe (Eyebrow, Bar, Sub/Card/Pill).
BUDGET_COVER, BUDGET_STEP, BUDGET_CTA = 620, 470, 470


def build(slide):
    n = slide["n"]
    if n == 1:
        # Reihenfolge: Foto schlaegt Text-Hook schlaegt gebrandetes Cover.
        if slide.get("photo"):
            return build_photo_hook(slide)
        if slide.get("hook"):
            return build_native_hook(slide)
        size = fit_headline(slide["headline"], slide.get("script_word"), BUDGET_COVER)
        inner = (f"<div class='eyebrow'>{slide['eyebrow']}</div>"
                 f"<div class='headline' style='font-size:{size}px'>"
                 f"{headline_html(slide['headline'], slide.get('script_word'), size)}</div>"
                 f"<div class='bar'></div>"
                 f"<div class='sub'>{slide['subline']}</div>"
                 f"<div class='pill'>SWIPE FOR THE ROUTINE</div>")
        return page(inner, high=True)
    if n in (2, 3, 4):
        size = fit_headline(slide["headline"], None, BUDGET_STEP)
        bullets = "".join(f"<div class='bullet'><span class='dot'></span>{b}</div>"
                          for b in slide["bullets"])
        inner = (f"<div class='eyebrow'>{slide['eyebrow']}</div>"
                 f"<div class='headline' style='font-size:{size}px'>"
                 f"{headline_html(slide['headline'], None, size)}</div>"
                 f"<div class='bar'></div>"
                 f"<div class='card'>{bullets}</div>")
        return page(inner, ghost=slide["ghost_number"])
    pill_raw = slide.get("pill", 'COMMENT "GLOW"')
    # Klasse am Rohtext messen, nicht am escapten — &quot; blaeht jedes
    # Anfuehrungszeichen auf 6 Zeichen auf und wuerde den kurzen Default
    # faelschlich als "long" einstufen.
    pill_cls = "pill long" if len(pill_raw) > 20 else "pill"
    pill = html.escape(pill_raw)
    after = slide.get("after_pill", "and I'll send it over.")
    size = fit_headline(slide["headline"], slide.get("script_word"), BUDGET_CTA)
    inner = (f"<div class='eyebrow'>{slide['eyebrow']}</div>"
             f"<div class='headline' style='font-size:{size}px'>"
             f"{headline_html(slide['headline'], slide.get('script_word'), size)}</div>"
             f"<div class='bar'></div>"
             f"<div class='{pill_cls}'>{pill}</div>"
             f"<div class='after-pill'>{after}</div>"
             f"<div class='line2'>{slide['line2']}</div>"
             + (f"<div class='early'>{slide['early']}</div>"
                if slide.get("early") else ""))
    return page(inner)

W, H = 1080, 1440


def shoot(html_path, png_path):
    """wkhtmltoimage gibt es in dieser Umgebung nicht — headless Chromium
    rendert dasselbe HTML/CSS. Chromium liefert bei --window-size=W,H rund
    87px weniger echtes Viewport und fuellt den Rest weiss auf, darum bewusst
    zu hoch anfordern und danach exakt auf W×H beschneiden."""
    chrome = glob.glob("/opt/pw-browsers/chromium-*/chrome-linux/chrome")[0]
    subprocess.run([chrome, "--headless=new", "--disable-gpu", "--no-sandbox",
                    "--hide-scrollbars", "--force-device-scale-factor=1",
                    f"--window-size={W},{H + 240}",
                    f"--screenshot={png_path}",
                    f"file://{os.path.abspath(html_path)}"],
                   check=True, capture_output=True)
    im = Image.open(png_path)
    if im.size != (W, H):
        im = im.crop((0, 0, W, H))
    im.save(png_path, optimize=True)


def main(json_path, outdir):
    data = json.load(open(json_path))
    os.makedirs(outdir, exist_ok=True)
    slug = data["topic"].replace(" ", "-")[:30]
    for slide in data["slides"]:
        html_path = f"/tmp/slide_{slide['n']}.html"
        png_path = os.path.join(outdir, f"glowe_{slug}_{slide['n']}.png")
        open(html_path, "w").write(build(slide))
        shoot(html_path, png_path)
        os.remove(html_path)
        print("ok", png_path, Image.open(png_path).size)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
