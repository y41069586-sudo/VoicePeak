#!/usr/bin/env python3
"""Render-Service für den Glowé-TikTok-Autopiloten.

Ein POST /render mit zwei Bild-URLs baut die vier Slides und gibt vier
öffentlich abrufbare URLs zurück. Zapier lädt Dateien beim Ausführen des
Schritts sofort in den eigenen Speicher, deshalb reicht es, die Slides eine
Stunde lang vorzuhalten — der Buffer-Schritt läuft Sekunden nach dem Render.
"""

import os
import shutil
import sys
import tempfile
import threading
import time
import urllib.request
import uuid

from flask import Flask, jsonify, request, send_from_directory

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import glowe_slideshow as g  # noqa: E402

WORK = os.path.join(tempfile.gettempdir(), "glowe-slides")
TTL_SECONDS = 3600
MAX_BYTES = 20 * 1024 * 1024

os.makedirs(WORK, exist_ok=True)
app = Flask(__name__)
_lock = threading.Lock()


def sweep():
    """Abgelaufene Jobs wegräumen. Läuft bei jedem Render mit, damit der
    Container ohne Cron nicht vollläuft."""
    now = time.time()
    for name in os.listdir(WORK):
        path = os.path.join(WORK, name)
        try:
            if now - os.path.getmtime(path) > TTL_SECONDS:
                shutil.rmtree(path, ignore_errors=True)
        except OSError:
            pass


def download(url, dest):
    if not url.lower().startswith(("http://", "https://")):
        raise ValueError(f"Nur http(s)-URLs erlaubt, bekommen: {url[:60]}")
    req = urllib.request.Request(url, headers={"User-Agent": "glowe-render/1"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise ValueError("Quellbild größer als 20 MB")
    with open(dest, "wb") as f:
        f.write(data)


def base_url():
    """Hinter Cloud Run / Render terminiert der Proxy TLS, url_root meldet
    dann http. PUBLIC_BASE_URL sticht, sonst X-Forwarded-Proto."""
    if os.environ.get("PUBLIC_BASE_URL"):
        return os.environ["PUBLIC_BASE_URL"].rstrip("/")
    root = request.url_root.rstrip("/")
    proto = request.headers.get("X-Forwarded-Proto")
    if proto == "https" and root.startswith("http://"):
        root = "https://" + root[len("http://"):]
    return root


@app.get("/health")
def health():
    try:
        chrome = g.chrome_binary()
    except RuntimeError as e:
        return jsonify(ok=False, error=str(e)), 503
    return jsonify(ok=True, chrome=chrome, font_exists=os.path.exists(g.FONT_PATH))


@app.post("/render")
def render_slides():
    data = request.get_json(silent=True) or {}
    before, after = data.get("before_url"), data.get("after_url")
    if not before or not after:
        return jsonify(error="before_url und after_url sind Pflicht"), 400

    job = uuid.uuid4().hex
    out = os.path.join(WORK, job)
    os.makedirs(out, exist_ok=True)

    try:
        acne = os.path.join(out, "_before.jpg")
        clear = os.path.join(out, "_after.jpg")
        download(before, acne)
        download(after, clear)

        # Chromium-Aufrufe serialisieren: mehrere gleichzeitige Instanzen in
        # einem kleinen Container laufen sonst ins Speicherlimit.
        with _lock:
            g.photo_slide(acne, g.CAPTIONS[1], os.path.join(out, "slide1.jpg"))
            g.photo_slide(clear, g.CAPTIONS[2], os.path.join(out, "slide2.jpg"))
            g.render(g.analysis_html(g.circle_avatar(clear), 14),
                     os.path.join(out, "slide3.png"))
            g.render(g.routine_html(14), os.path.join(out, "slide4.png"))

        os.remove(acne)
        os.remove(clear)
    except Exception as e:
        shutil.rmtree(out, ignore_errors=True)
        app.logger.exception("render failed")
        return jsonify(error=f"{type(e).__name__}: {e}"), 502

    sweep()
    root = f"{base_url()}/s/{job}"
    return jsonify(
        job=job,
        slide1=f"{root}/slide1.jpg",
        slide2=f"{root}/slide2.jpg",
        slide3=f"{root}/slide3.png",
        slide4=f"{root}/slide4.png",
        expires_in_seconds=TTL_SECONDS,
    )


@app.get("/s/<job>/<path:name>")
def serve(job, name):
    # uuid4().hex ist der einzige gültige Job-Name — blockt Pfad-Tricks.
    if not job.isalnum() or len(job) != 32:
        return jsonify(error="ungültige Job-ID"), 400
    return send_from_directory(os.path.join(WORK, job), name,
                               max_age=TTL_SECONDS)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
