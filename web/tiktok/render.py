#!/usr/bin/env python3
"""Glowe Carousel Renderer v2 - bolder. JSON in, 5 PNG slides (1080x1440) out."""
import glob, json, os, subprocess, sys
from PIL import Image

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
.after-pill {{ font-size:44px; color:{BODY}; line-height:1.5; margin-top:40px; }}
.line2 {{ font-size:38px; color:{BODY}; line-height:1.5; margin-top:20px; }}
.logo {{
  position:absolute; bottom:60px; right:90px;
  font-family:'{FONT_SCRIPT}'; font-size:62px; color:{LAV};
}}
"""

RIBBON_SVG = f"""<svg class="ribbon" width="54" height="86" xmlns="http://www.w3.org/2000/svg">
<polygon points="0,0 54,0 54,86 27,64 0,86" fill="{LAV}"/></svg>"""

def page(inner, ghost=None):
    g = f'<div class="ghost">{ghost}</div>' if ghost else ""
    return (f"<!DOCTYPE html><html><head><meta charset='utf-8'>"
            f"<style>{BASE_CSS}</style></head><body>{g}{RIBBON_SVG}"
            f"<div class='content'>{inner}</div>"
            f"<div class='logo'>Glow&eacute;</div></body></html>")

def headline_html(text, script_word=None):
    words, out = text.split(), []
    for w in words:
        if script_word and w.strip("?!.,").lower() == script_word.lower():
            out.append(f"<span class='script'>{w.lower()}</span>")
        else:
            out.append(w.upper())
    return " ".join(out)

def build(slide):
    n = slide["n"]
    if n == 1:
        inner = (f"<div class='eyebrow'>{slide['eyebrow']}</div>"
                 f"<div class='headline'>{headline_html(slide['headline'], slide.get('script_word'))}</div>"
                 f"<div class='bar'></div>"
                 f"<div class='sub'>{slide['subline']}</div>"
                 f"<div class='pill'>SWIPE FOR THE ROUTINE</div>")
        return page(inner)
    if n in (2, 3, 4):
        bullets = "".join(f"<div class='bullet'><span class='dot'></span>{b}</div>"
                          for b in slide["bullets"])
        inner = (f"<div class='eyebrow'>{slide['eyebrow']}</div>"
                 f"<div class='headline'>{headline_html(slide['headline'])}</div>"
                 f"<div class='bar'></div>"
                 f"<div class='card'>{bullets}</div>")
        return page(inner, ghost=slide["ghost_number"])
    inner = (f"<div class='eyebrow'>{slide['eyebrow']}</div>"
             f"<div class='headline'>{headline_html(slide['headline'], slide.get('script_word'))}</div>"
             f"<div class='bar'></div>"
             f"<div class='pill'>COMMENT &quot;GLOW&quot;</div>"
             f"<div class='after-pill'>and I'll send it over.</div>"
             f"<div class='line2'>{slide['line2']}</div>")
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
