FROM python:3.11-slim

# chromium rendert Slide 3 und 4, fonts-liberation liefert die Bold-Variante
# für das Text-Overlay auf Slide 1 und 2 (FONT_PATH in glowe_slideshow.py),
# fonts-noto-color-emoji die Emoji im Routine-Screen (🌿 ☀️ 🏠 📈).
RUN apt-get update && apt-get install -y --no-install-recommends \
        chromium \
        fonts-liberation \
        fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN=/usr/bin/chromium \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY service/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY glowe_slideshow.py ./
COPY service/app.py ./service/

# Ein Worker mit Threads: die Chromium-Aufrufe sind ohnehin über einen Lock
# serialisiert, mehrere Worker würden nur Speicher fressen. Timeout großzügig,
# vier Screenshots brauchen je nach Instanz ein paar Sekunden.
CMD exec gunicorn --bind 0.0.0.0:${PORT:-8080} \
        --workers 1 --threads 4 --timeout 180 \
        service.app:app
