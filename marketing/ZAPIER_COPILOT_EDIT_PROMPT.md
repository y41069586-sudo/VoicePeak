# Zapier-Copilot-Prompt — bestehenden Zap korrigieren

Für den Fall, dass Copilot den Zap schon gebaut hat, er aber nicht stimmt.
Beschreibt den Ziel-Zustand statt einer Änderung — funktioniert deshalb egal,
was gerade drinsteht.

**Vor dem Einfügen:** `<MEINE-CLOUD-RUN-URL>` unten durch die echte URL des
Render-Service ersetzen (aus `gcloud run services describe glowe-render
--region europe-west1 --format='value(status.url)'`).

---

Der Zap existiert schon — bitte **nicht neu anlegen**, sondern bearbeiten, bis
er exakt der folgenden Struktur entspricht. Fehlende Schritte an der richtigen
Position einfügen, abweichend konfigurierte korrigieren, überflüssige löschen.

**Wichtigster Punkt:** Am Ende muss Buffer **vier Bilder** bekommen, nicht
eins. Ein einzelnes Foto ist kein Slideshow-Post.

## Schritt 1 — Schedule by Zapier

Trigger „Every Day", 17:00 Uhr.

## Schritt 2 — Code by Zapier (JavaScript)

Keine Input-Felder. Dieser Code würfelt pro Lauf eine andere Person, anderen
Raum, anderes Licht, anderes Shirt und baut daraus die zwei Bild-Prompts.
Vorher- und Nachher-Bild bekommen bewusst dieselbe Person und denselben
Hautton, aber unterschiedlichen Raum und unterschiedliches Shirt.

```js
const pick = a => a[Math.floor(Math.random() * a.length)];
const pickBut = (a, no) => pick(a.filter(x => x !== no));

const person = pick([
  "young woman", "young man", "woman in her early twenties",
  "man in his early twenties", "young woman in her late teens",
  "young man in his late teens"
]);
const tone = pick([
  "fair", "light olive", "medium tan", "warm brown", "deep brown", "light brown"
]);
const light = pick([
  "bathroom lighting", "natural indoor lighting", "soft window daylight",
  "warm evening indoor light", "flat overcast daylight from a window"
]);
const rooms = ["bathroom", "bedroom", "hallway", "kitchen", "living room"];
const tops  = ["grey", "white", "black", "olive green", "navy", "cream"];
const roomA = pick(rooms), roomB = pickBut(rooms, roomA);
const topA  = pick(tops),  topB  = pickBut(tops, topA);

const NOTEXT = "Do not add any text, words, letters, numbers, captions, " +
  "watermarks or overlays anywhere in the image.";

const before =
`Extreme close-up of one cheek and jawline of a ${person} with ${tone} skin, head slightly tilted, only part of the face visible. Casual iPhone front-camera selfie, ${light}, realistic skin texture with visible pores, moderate inflammatory acne with red pimples, papules and post-acne marks across the cheek and jawline, uneven skin tone, wearing a plain ${topA} t-shirt, ${roomA} in the background, no makeup, no retouching, no perfect skin, authentic smartphone photo, handheld, candid TikTok slideshow aesthetic, impossible to distinguish from a real human photo. ${NOTEXT}`;

const after =
`Extreme close-up of one cheek and jawline of the same ${person} with ${tone} skin, head slightly tilted, only part of the face visible. Casual iPhone front-camera selfie, spontaneous handheld shot, ${light}. Naturally healed skin with a healthy hydrated glass-skin glow while preserving realistic pores and subtle skin texture. No acne, no redness, no makeup, no retouching, no beauty filter, not perfect or plastic-looking. Wearing a plain ${topB} t-shirt, ${roomB} in the background.

Realistic smartphone camera imperfections including slight sensor noise, natural exposure, realistic white balance and slightly imperfect framing. Authentic candid TikTok skincare transformation aesthetic. Looks exactly like a real person took this on an iPhone. Impossible to distinguish from a genuine smartphone photo. No AI look, no CGI, no studio lighting, no cinematic lighting, no HDR, no beauty filter. ${NOTEXT}`;

output = [{ before, after, person, tone, roomA, roomB, topA, topB }];
```

## Schritt 3 — ChatGPT (OpenAI): Generate An Image (Vorher)

- Prompt: `{{2__before}}`
- Model **gpt-image-1**, Size **1024x1536**, Quality **medium**, File Type **jpeg**, Results **1**
- Quality **nicht** auf `high` — das läuft in Zapiers 60-Sekunden-Limit.

## Schritt 4 — Delay by Zapier

**15 Sekunden.** Nicht weglassen. Zwei gleichzeitige Calls auf dieselbe
OpenAI-Connection geben sporadisch `401 „This endpoint is only accessible by
projects with geography restrictions enabled"`. Nacheinander tritt der Fehler
nicht auf.

## Schritt 5 — ChatGPT (OpenAI): Generate An Image (Nachher)

Identische Settings wie Schritt 3, Prompt `{{2__after}}`.

Die beiden Bild-Schritte müssen **in einem einzigen linearen Pfad**
hintereinander liegen — nicht in zwei parallelen Zap-Pfaden.

## Schritt 6 — Webhooks by Zapier: POST

Dieser Schritt baut die vier Slides. **Ohne ihn gibt es kein Text-Overlay und
keine App-Screens** — dann landet nur ein nacktes Foto in Buffer.

- URL: `<MEINE-CLOUD-RUN-URL>/render`
- Payload Type: **JSON**
- Data:
  - `before_url` = Bild-URL aus Schritt 3
  - `after_url` = Bild-URL aus Schritt 5
- Unwrap Arrays: no

Antwort enthält `slide1`, `slide2`, `slide3`, `slide4` als abrufbare URLs.

## Schritt 7 — Filter by Zapier

Nur fortfahren, wenn `slide4` aus Schritt 6 existiert und nicht leer ist.

## Schritt 8 — ChatGPT (OpenAI): Conversation

> Du schreibst TikTok-Captions für Glowé, eine iOS-App, die per Selfie die Haut
> scannt, 8 Scores von 0–100 gibt und einen 14-Tage-Plan erstellt.
> Schreib für einen Vorher/Nachher-Slideshow-Post:
> 1. einen Titel (max. 60 Zeichen, Hook, kein Heilversprechen)
> 2. eine Caption (max. 150 Zeichen, locker, erste Person, CTA „Glowé im App Store")
> 3. genau 8 Hashtags, Mix aus groß und Nische, deutsch und englisch
> 4. einen Vorschlag für einen aktuell trendenden TikTok-Sound aus dem
>    Beauty-/Glow-up-Bereich
> Die Caption MUSS den Hinweis enthalten, dass die gezeigten Gesichter
> KI-generiert sind.
> Antworte als JSON: {"titel":…,"caption":…,"hashtags":[…],"sound_vorschlag":…}

Variante mitgeben: `{{2__person}}`, `{{2__roomA}}`.

## Schritt 9 — Buffer: Add to Queue

- Mein TikTok-Kanal
- Bilder: `slide1`, `slide2`, `slide3`, `slide4` aus Schritt 6, **in genau
  dieser Reihenfolge** — alle vier, nicht nur eins
- Text: Caption + Hashtags aus Schritt 8
- Als **Draft** einplanen, nicht direkt veröffentlichen
- `sound_vorschlag` mit in die Notiz

## Prüf bitte gezielt diese fünf Punkte

1. Gibt es **zwei** Bild-Schritte (Vorher und Nachher)? Häufigster Fehler: nur einer.
2. Existiert der **Webhook-Schritt** überhaupt? Ohne ihn kein Slideshow-Post.
3. Bekommt Buffer **alle vier** Slide-URLs in der richtigen Reihenfolge?
4. Steht Image Quality auf **medium**, nicht `high`?
5. Liegen die Bild-Schritte **seriell** mit Delay dazwischen, nicht parallel?
