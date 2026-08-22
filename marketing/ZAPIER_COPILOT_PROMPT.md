# Zapier-Copilot-Prompt — SkinFix TikTok-Slideshow-Autopilot

Alles unterhalb der Linie in **Zapier Copilot** einfügen. Er baut daraus den Zap.

Vorher einmalig bereitstellen (Copilot kann das nicht für dich anlegen):

1. **Render-Service.** `glowe_slideshow.py` als kleinen HTTP-Dienst deployen
   (Cloud Run / Render / Railway — Dockerfile mit `python:3.11-slim`,
   `pip install pillow` + Chromium). Ein `POST /render` mit
   `{"before_url": …, "after_url": …}` gibt `{"slide1": …, "slide4": …}` als
   4 öffentliche URLs zurück. Das ist der einzige Weg, der pixelgleich das
   liefert, was lokal schon gebaut ist — Bannerbear/Cloudinary-Templates
   müssten Text-Overlay, 9:16-Cover-Crop und Kreis-Avatar neu nachbauen.
2. **Buffer**-Kanal für TikTok verbunden.
3. **OpenAI**-Connection in Zapier neu authentifiziert, falls sie älter ist —
   sie fliegt still raus und der Zap failt dann mit „default connection no
   longer exists".

---

Baue mir einen Zap, der einmal täglich einen kompletten TikTok-Slideshow-Post
für meine iOS-Skincare-App **SkinFix** erzeugt und in Buffer einplant. Jeder Post
muss sich vom vorherigen unterscheiden, damit es keine Duplicate-Content-
Drosselung gibt.

**Diese Tools/Apps sollst du verwenden — bitte genau diese:**

- **Schedule by Zapier** (Trigger, „Every Day")
- **Code by Zapier** (JavaScript, Schritt 2 — Varianten-Generator)
- **ChatGPT (OpenAI)** → Action **„Generate An Image"** (Schritte 3 und 4)
- **Webhooks by Zapier** → **POST** (Schritt 5 — Slides rendern)
- **ChatGPT (OpenAI)** → Action **„Conversation"** (Schritt 6 — Caption/Titel/Hashtags)
- **Buffer** → Action **„Add to Queue"** (Schritt 7)
- **Filter by Zapier** und **Delay by Zapier**, wo unten beschrieben

### Schritt 1 — Trigger

Schedule by Zapier, jeden Tag um 17:00 Uhr (beste TikTok-Zeit DE).

### Schritt 2 — Code by Zapier (JavaScript), Varianten-Generator

Keine Input-Felder nötig. Dieser Code würfelt pro Lauf eine andere Person,
anderen Raum, anderes Licht, anderes Shirt und baut daraus die zwei
Bild-Prompts. **Wichtig:** Vorher-/Nachher-Bild bekommen bewusst denselben
Personen- und Hauttyp, aber unterschiedlichen Raum und unterschiedliches
Shirt — das verkauft „30 Tage später" glaubwürdiger.

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
const roomA = pick(["bathroom", "bedroom", "hallway", "kitchen", "living room"]);
const roomB = pickBut(["bathroom", "bedroom", "hallway", "kitchen", "living room"], roomA);
const topA  = pick(["grey", "white", "black", "olive green", "navy", "cream"]);
const topB  = pickBut(["grey", "white", "black", "olive green", "navy", "cream"], topA);

const NOTEXT = "Do not add any text, words, letters, numbers, captions, " +
  "watermarks or overlays anywhere in the image.";

const before =
`Extreme close-up of one cheek and jawline of a ${person} with ${tone} skin, head slightly tilted, only part of the face visible. Casual iPhone front-camera selfie, ${light}, realistic skin texture with visible pores, moderate inflammatory acne with red pimples, papules and post-acne marks across the cheek and jawline, uneven skin tone, wearing a plain ${topA} t-shirt, ${roomA} in the background, no makeup, no retouching, no perfect skin, authentic smartphone photo, handheld, candid TikTok slideshow aesthetic, impossible to distinguish from a real human photo. ${NOTEXT}`;

const after =
`Extreme close-up of one cheek and jawline of the same ${person} with ${tone} skin, head slightly tilted, only part of the face visible. Casual iPhone front-camera selfie, spontaneous handheld shot, ${light}. Naturally healed skin with a healthy hydrated glass-skin glow while preserving realistic pores and subtle skin texture. No acne, no redness, no makeup, no retouching, no beauty filter, not perfect or plastic-looking. Wearing a plain ${topB} t-shirt, ${roomB} in the background.

Realistic smartphone camera imperfections including slight sensor noise, natural exposure, realistic white balance and slightly imperfect framing. Authentic candid TikTok skincare transformation aesthetic. Looks exactly like a real person took this on an iPhone. Impossible to distinguish from a genuine smartphone photo. No AI look, no CGI, no studio lighting, no cinematic lighting, no HDR, no beauty filter. ${NOTEXT}`;

output = [{ before, after, person, tone, roomA, roomB, topA, topB }];
```

### Schritt 3 — ChatGPT (OpenAI): Generate An Image (Vorher-Bild)

- Prompt: `{{2__before}}`
- Model: **gpt-image-1**
- Image Size: **1024x1536**
- Image Quality: **medium** — **nicht** `high`. `high` läuft in Zapiers
  60-Sekunden-Limit und der Zap bricht ab.
- File Type: **jpeg**
- Number of results: 1

### Schritt 4 — ChatGPT (OpenAI): Generate An Image (Nachher-Bild)

Identische Settings, Prompt `{{2__after}}`.

**Wichtig — die beiden Bild-Schritte müssen streng nacheinander laufen, nie in
zwei parallelen Zap-Pfaden.** Zwei gleichzeitige Calls auf dieselbe
OpenAI-Connection geben sporadisch `401 „This endpoint is only accessible by
projects with geography restrictions enabled"`. Nacheinander tritt der Fehler
nicht auf. Setze zwischen Schritt 3 und 4 zur Sicherheit **Delay by Zapier,
15 Sekunden**.

### Schritt 5 — Webhooks by Zapier: POST (Slides bauen)

- URL: die `/render`-URL meines Render-Service
- Payload Type: **JSON**
- Data: `before_url` = Bild-URL aus Schritt 3, `after_url` = Bild-URL aus Schritt 4
- Antwort enthält `slide1` … `slide4` als öffentliche URLs

Der Service setzt selbst: 9:16-Cover-Crop, Text-Overlay „How I got my skin to
go from this" auf Slide 1 und „to this" auf Slide 2, den Score-Screen mit
Kreis-Avatar aus dem Nachher-Bild (Slide 3) und den Routine-Screen (Slide 4).

Danach **Filter by Zapier**: nur weiter, wenn `slide4` existiert und nicht leer
ist — sonst kein halber Post in der Queue.

### Schritt 6 — ChatGPT (OpenAI): Conversation (Caption, Titel, Hashtags)

System/Prompt sinngemäß:

> Du schreibst TikTok-Captions für SkinFix, eine iOS-App, die per Selfie die Haut
> scannt, 8 Scores von 0–100 gibt und einen 14-Tage-Plan erstellt.
> Schreib mir für einen Vorher/Nachher-Slideshow-Post:
> 1. einen Titel (max. 60 Zeichen, Hook, kein Clickbait-Versprechen)
> 2. eine Caption (max. 150 Zeichen, locker, erste Person, ein Call-to-Action
>    „SkinFix im App Store")
> 3. genau 8 Hashtags, Mix aus groß und Nische, deutsch und englisch
> Variiere Wortwahl und Hook stark gegenüber üblichen Skincare-Captions.
> Gib JSON zurück: {"titel": …, "caption": …, "hashtags": [...]}
> Die Caption MUSS den Hinweis enthalten, dass die gezeigten Gesichter
> KI-generiert sind.

Variante pro Lauf mitgeben (`{{2__person}}`, `{{2__roomA}}`), damit die Caption
zum Bild passt.

### Schritt 7 — Buffer: Add to Queue

- Kanal: mein TikTok-Kanal
- Bilder: `slide1`, `slide2`, `slide3`, `slide4` **in genau dieser Reihenfolge**
- Text: Caption + Hashtags aus Schritt 6

---

## Zwei Dinge, die der Zap nicht allein kann — bitte im Zap als Notiz hinterlegen

**1. Trending-Sound.** TikToks Content-Posting-API erlaubt es nicht, einem
Foto-Carousel einen bestimmten Trending-Sound zuzuweisen; Buffer reicht das
entsprechend nicht durch. Praktikabel ist: Buffer plant den Post als **Draft**
statt direkt zu veröffentlichen, und der Sound wird beim Freigeben in der
TikTok-App in 5 Sekunden ausgewählt. Lass Schritt 6 zusätzlich ein Feld
`sound_vorschlag` ausgeben (aktueller Trending-Sound aus dem Beauty-/
Glow-up-Bereich, z. B. ein ruhiger Slowed-Remix), und häng es an die
Buffer-Notiz — dann steht beim Freigeben schon da, was gewählt werden soll.
Prüf das aber gegen Buffers aktuelle TikTok-Optionen, das ändert sich.

**2. KI-Kennzeichnung — nicht optional.** Die zwei Gesichter sind
KI-generiert und fotorealistisch. TikTok verlangt dafür das
AI-generated-Label, und in Deutschland ist ein ungekennzeichneter
Vorher/Nachher-Vergleich mit erfundenen Personen irreführende Werbung nach
UWG. Zusätzlich zum Hinweis in der Caption muss beim Freigeben in der
TikTok-App der **„AI-generated content"-Schalter** gesetzt werden. Der Hook
funktioniert mit Label genauso gut — das ist kein Reichweiten-Verlust, aber
ohne Label ist es ein Abmahnrisiko.

## Fehlerbilder, die real aufgetreten sind — bau Retries dafür ein

| Fehler | Ursache | Fix im Zap |
|---|---|---|
| `timed out after 60s` bei der Bildgenerierung | quality zu hoch / OpenAI langsam | quality `medium`, Zap-Retry aktivieren |
| `401 geography restrictions enabled` | zwei parallele OpenAI-Calls | Bildschritte streng seriell + Delay dazwischen |
| `default connection no longer exists` | OpenAI-Connection abgelaufen | Connection in Zapier neu authentifizieren |
| Schrift im Bild („30 days later") | Datums-/Zeitwörter im Prompt | keine Zeitangaben im Prompt, `NOTEXT`-Zusatz behalten |
