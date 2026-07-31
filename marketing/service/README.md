# Glowé Render-Service

Nimmt zwei Bild-URLs entgegen, baut daraus die vier TikTok-Slides und gibt vier
abrufbare URLs zurück. Genau der Code, der die Slides auch lokal baut — der
Service ist nur eine HTTP-Hülle um `glowe_slideshow.py`.

## API

### `POST /render`

```json
{ "before_url": "https://…/akne.jpg", "after_url": "https://…/clear.jpg" }
```

Antwort `200`:

```json
{
  "job": "112fa43821754e1d851dad5c17c12436",
  "slide1": "https://…/s/112fa…/slide1.jpg",
  "slide2": "https://…/s/112fa…/slide2.jpg",
  "slide3": "https://…/s/112fa…/slide3.png",
  "slide4": "https://…/s/112fa…/slide4.png",
  "expires_in_seconds": 3600
}
```

`400` bei fehlenden Feldern, `502` wenn ein Quellbild nicht ladbar ist oder
Chromium den Screenshot nicht erzeugt. Kein Teilergebnis — entweder alle vier
Slides oder ein Fehler. Das ist Absicht: sonst landet ein halber Post in der
Buffer-Queue.

### `GET /health`

Meldet, ob Chromium gefunden wurde und die Schriftart existiert. Als
Startup-Probe brauchbar.

### `GET /s/<job>/<datei>`

Liefert die gerenderten Slides aus.

## Lebensdauer der Slides

Slides liegen eine Stunde im Container und werden bei jedem neuen Render
aufgeräumt. Das reicht, weil Zapier Dateien beim Ausführen des Schritts sofort
in den eigenen Speicher zieht — der Buffer-Schritt läuft Sekunden nach dem
Render, nicht erst zum geplanten Posting-Zeitpunkt.

Wenn du die Slides dauerhaft brauchst, häng in `app.py` nach dem Rendern einen
Upload zu S3/GCS an und gib stattdessen diese URLs zurück.

## Deploy auf Google Cloud Run

Aus dem Verzeichnis **`marketing/`** (nicht aus `service/`) — das Dockerfile
erwartet `marketing/` als Build-Kontext:

```bash
cd marketing

gcloud run deploy glowe-render \
  --source . \
  --region europe-west1 \
  --allow-unauthenticated \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300 \
  --concurrency 4
```

**`--memory 2Gi` ist nicht optional.** Chromium fällt mit den 512 MB Default
beim Screenshot um, und `/tmp` ist auf Cloud Run eine RAM-Disk, die
mitzählt. Ebenso `--timeout 300`: vier Screenshots plus zwei Downloads
brauchen auf einer kalten Instanz gut über eine Minute.

Danach die Dienst-URL testen:

```bash
URL=$(gcloud run services describe glowe-render --region europe-west1 \
      --format='value(status.url)')

curl "$URL/health"

curl -X POST "$URL/render" -H 'Content-Type: application/json' \
  -d '{"before_url":"https://picsum.photos/1024/1536",
       "after_url":"https://picsum.photos/1024/1537"}'
```

Diese `$URL/render` kommt in Schritt 5 des Zaps.

## Deploy auf Render.com

Neuer **Web Service** → Repo verbinden → Root Directory `marketing`,
Runtime **Docker**. Instance Type mindestens **Standard** (2 GB RAM);
der Free-Tier mit 512 MB reicht für Chromium nicht. `PORT` setzt Render
selbst.

## Lokal testen

```bash
cd marketing
pip install -r service/requirements.txt
python3 service/app.py           # Port 8080

# in einer zweiten Shell, mit zwei erreichbaren Bild-URLs:
curl -X POST http://127.0.0.1:8080/render -H 'Content-Type: application/json' \
  -d '{"before_url":"…","after_url":"…"}'
```

Lokal findet das Script Chromium im Playwright-Bundle unter `/opt/pw-browsers`.
Im Container zeigt `CHROME_BIN` auf `/usr/bin/chromium`. Beides regelt
`chrome_binary()` in `glowe_slideshow.py`.

## Absicherung

Der Dienst steht offen im Netz und generiert auf Zuruf Bilder. Für den
Eigengebrauch reicht ein geteiltes Geheimnis: in `app.py` einen Header gegen
eine Env-Var prüfen und in Zapier als Header mitschicken.

```python
if os.environ.get("RENDER_TOKEN") and \
        request.headers.get("X-Render-Token") != os.environ["RENDER_TOKEN"]:
    return jsonify(error="unauthorized"), 401
```

Sonst rendert dir irgendwann jemand anderes seine Bilder auf deine Rechnung.
