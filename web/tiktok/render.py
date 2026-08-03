#!/usr/bin/env python3
"""Glowe Carousel Renderer v2 - bolder. JSON in, 5 PNG slides (1080x1440) out."""
import glob, html, json, os, subprocess, sys
from PIL import Image, ImageFont

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

SANS_BOLD = "/usr/share/fonts/opentype/inter/InterDisplay-Bold.otf"
COL_W = 900          # Breite der .content-Spalte
HEAD_MAX, HEAD_MIN = 132, 68
SCRIPT_RATIO = 180 / 132   # .script haengt proportional an der Headline


def _wrap(words, font, tracking):
    """Greedy-Umbruch wie im Browser, inkl. letter-spacing."""
    lines, cur = [], []
    for w in words:
        trial = cur + [w]
        s = " ".join(trial)
        if not cur or font.getlength(s) + tracking * len(s) <= COL_W:
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
