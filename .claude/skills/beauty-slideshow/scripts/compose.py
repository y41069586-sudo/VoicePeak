#!/usr/bin/env python3
"""
OpenAI returns 1024x1536 (2:3). TikTok wants 1080x1920 (9:16).

Scale to width-match 1920 height, then centre-crop the sides. Nothing is
added, nothing is stretched, no bars — 100px is removed from each side.
That is why every image prompt must keep all text inside the central 80%
of the frame.

Usage:  python3 compose.py <indir-or-files...> <outdir>
"""
import os, sys
from PIL import Image

W, H = 1080, 1920


def compose(src, dst):
    im = Image.open(src).convert("RGB")
    scale = max(W / im.width, H / im.height)
    new = im.resize((round(im.width * scale), round(im.height * scale)),
                    Image.LANCZOS)
    left = (new.width - W) // 2
    top = (new.height - H) // 2
    new.crop((left, top, left + W, top + H)).save(dst, "PNG")
    return dst


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: compose.py <files-or-dir> <outdir>")
    *ins, outdir = sys.argv[1:]
    files = []
    for p in ins:
        if os.path.isdir(p):
            files += [os.path.join(p, f) for f in sorted(os.listdir(p))
                      if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))]
        else:
            files.append(p)
    os.makedirs(outdir, exist_ok=True)
    for i, f in enumerate(files, 1):
        out = os.path.join(outdir, f"slide_{i}.png")
        compose(f, out)
        print(f"{out}  {Image.open(out).size}")


if __name__ == "__main__":
    main()
