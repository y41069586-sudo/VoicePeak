# Zapier-Copilot-Prompt — die drei konkreten Fehler beheben

Gezielter Korrektur-Prompt, nachdem der erste Zap-Bau schief lief. Beobachteter
Zustand im Buffer-Draft: fünf rohe Fotos ohne Text-Overlay und ohne App-Screens,
Caption enthält den rohen JSON-Block.

**Vor dem Einfügen:** `<MEINE-CLOUD-RUN-URL>` durch die echte Service-URL
ersetzen.

---

Am bestehenden Zap sind drei Dinge falsch. Bitte genau diese beheben, den Rest
so lassen.

## Fehler 1 — Es gibt zu viele Bild-Schritte

Aktuell erzeugt der Zap offenbar vier oder fünf Bilder. Das ist falsch gedacht:
Der Post hat zwar vier Slides, aber es werden nur **zwei Fotos** generiert —
die restlichen zwei Slides sind App-Screens, die ein externer Dienst rendert.

- Es dürfen **genau zwei** „ChatGPT (OpenAI) → Generate An Image"-Schritte
  existieren: einer mit `{{before}}`, einer mit `{{after}}` aus dem Code-Schritt.
- **Alle weiteren Generate-An-Image-Schritte löschen.**
- In beiden verbleibenden Schritten „Number of desired results" auf **1** setzen.
- Beide müssen seriell hintereinander liegen, mit einem **Delay by Zapier,
  15 Sekunden** dazwischen — nicht parallel.

## Fehler 2 — Der Render-Schritt fehlt komplett

Das ist die Hauptursache dafür, dass in Buffer nackte Fotos landen statt
fertiger Slides. **Füge nach dem zweiten Bild-Schritt ein:**

**Webhooks by Zapier → POST**

- URL: `<MEINE-CLOUD-RUN-URL>/render`
- Payload Type: **JSON**
- Data:
  - `before_url` = Bild-URL aus dem ersten Generate-An-Image-Schritt
  - `after_url` = Bild-URL aus dem zweiten Generate-An-Image-Schritt
- Unwrap Arrays: no

Die Antwort enthält vier Felder: `slide1`, `slide2`, `slide3`, `slide4`.
Dieser Dienst baut das Text-Overlay und die beiden App-Screens. Ohne ihn gibt
es keinen Slideshow-Post.

Direkt danach ein **Filter by Zapier**: nur fortfahren, wenn `slide4` aus dem
Webhook-Schritt existiert und nicht leer ist.

## Fehler 3 — Die Caption enthält rohes JSON

Im Buffer-Post steht aktuell wörtlich
`{"titel":"…","caption":"…","hashtags":[…],"sound_vorschlag":"…"}`.
Der ChatGPT-Schritt gibt JSON zurück, und das wurde komplett ins Textfeld
gemappt. **Füge nach dem ChatGPT-Caption-Schritt ein:**

**Code by Zapier → Run JavaScript**

Input Data: `raw` = die Antwort des ChatGPT-Caption-Schritts.

```js
let t = String(inputData.raw || "");
// ChatGPT verpackt JSON gern in ```json … ``` — auf das Objekt zuschneiden
const a = t.indexOf("{"), b = t.lastIndexOf("}");
let d = {};
if (a !== -1 && b > a) {
  try { d = JSON.parse(t.slice(a, b + 1)); } catch (e) { d = {}; }
}
const tags = Array.isArray(d.hashtags) ? d.hashtags.join(" ") : (d.hashtags || "");
output = [{
  titel: d.titel || "",
  caption: d.caption || "",
  hashtags: tags,
  sound: d.sound_vorschlag || "",
  post_text: [d.caption || "", tags].filter(Boolean).join("\n\n")
}];
```

## Der Buffer-Schritt am Ende

- Bilder: **genau vier**, und zwar `slide1`, `slide2`, `slide3`, `slide4` aus
  dem **Webhook-Schritt** — nicht die Bild-URLs aus den OpenAI-Schritten.
  Reihenfolge exakt 1, 2, 3, 4.
- Text: **nur** `{{post_text}}` aus dem Code-Schritt. Nicht die rohe
  ChatGPT-Antwort.
- `{{sound}}` und `{{titel}}` gehören nicht in den Post-Text — die höchstens in
  eine Notiz.
- Als **Draft** einplanen, nicht direkt veröffentlichen.

## Zum Schluss bitte gegenprüfen

1. Genau zwei Generate-An-Image-Schritte, beide mit Results = 1?
2. Existiert der Webhooks-POST-Schritt, und zeigen `before_url`/`after_url` auf
   die beiden Bild-Schritte?
3. Bekommt Buffer die vier `slideN`-URLs aus dem Webhook-Schritt — und nicht
   die OpenAI-Bilder?
4. Steht im Buffer-Textfeld `post_text` statt der rohen ChatGPT-Antwort?
