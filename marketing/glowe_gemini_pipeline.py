#!/usr/bin/env python3
"""
Glowe - automatischer Bild-Teil der Slideshow via Gemini 3 Pro (direkte API).

    python3 glowe_gemini_pipeline.py <style-dir> <out-dir> [--same-person]

    <style-dir> enthaelt:
        ref-day0.png      Stil-Referenz fuer das Vorher-Bild (Pose/Framing/Vibe)
        ref-day14.png     Stil-Referenz fuer das Nachher-Bild
        prompt-day0.txt   Prompt-Template Vorher (auto-extrahiert oder von Hand)
        prompt-day14.txt  Prompt-Template Nachher

    Ablauf: 2 Kandidaten fuer Bild 1 -> Gemini-Judge waehlt das echtere ->
    Bild 2 als Identitaets-Edit des Gewinners im Stil von ref-day14.
    Ergebnis: <out-dir>/akne.jpg + <out-dir>/clear.jpg
    (danach wie gehabt: glowe_full_auto.py fuer die 4 Slides)

    API-Key: env GEMINI_API_KEY (Secret der Umgebung), nie im Repo.
    Standard: NEUE Person pro Run (der Feed soll nicht immer dieselbe
    "Kundin"/"Kunden" zeigen). --same-person erzwingt die Referenz-Person.
"""
import base64, json, os, subprocess, sys, tempfile

API = "https://generativelanguage.googleapis.com/v1beta/models/{m}:generateContent"
IMAGE_MODEL = "gemini-3-pro-image-preview"
TEXT_MODELS = ["gemini-2.5-flash", "gemini-flash-latest", "gemini-2.5-pro"]


def call(model, parts, want_image, key):
    body = {"contents": [{"parts": parts}]}
    if want_image:
        body["generationConfig"] = {"responseModalities": ["IMAGE"],
                                    "imageConfig": {"aspectRatio": "9:16"}}
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump(body, f); req = f.name
    try:
        r = subprocess.run(["curl", "-sS", "--max-time", "300", "--retry", "5",
                            "--retry-delay", "12", "--retry-all-errors", "-X", "POST",
                            API.format(m=model), "-H", "Content-Type: application/json",
                            "-H", f"x-goog-api-key: {key}", "-d", f"@{req}"],
                           capture_output=True, text=True, check=True)
        resp = json.loads(r.stdout)
    finally:
        os.unlink(req)
    if "error" in resp:
        raise RuntimeError(resp["error"].get("message", "?")[:300])
    out_parts = resp["candidates"][0]["content"]["parts"]
    if want_image:
        img = next(p for p in out_parts if p.get("inlineData"))
        return base64.b64decode(img["inlineData"]["data"])
    return "".join(p.get("text", "") for p in out_parts).strip()


def text_call(parts, key):
    last = None
    for m in TEXT_MODELS:
        try:
            return call(m, parts, False, key)
        except Exception as e:
            last = e
    raise RuntimeError(f"kein Textmodell erreichbar: {last}")


def img_part(data):
    return {"inlineData": {"mimeType": "image/jpeg",
                           "data": base64.b64encode(data).decode()}}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) < 2:
        sys.exit(__doc__)
    style, out = args
    same_person = "--same-person" in sys.argv
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not key:
        sys.exit("GEMINI_API_KEY fehlt (Umgebungs-Secret setzen)")
    os.makedirs(out, exist_ok=True)

    ref0 = open(f"{style}/ref-day0.png", "rb").read()
    ref14 = open(f"{style}/ref-day14.png", "rb").read()
    p0 = open(f"{style}/prompt-day0.txt").read().strip()
    p14 = open(f"{style}/prompt-day14.txt").read().strip()

    person = ("Recreate the SAME person as in the reference image."
              if same_person else
              "Show a NEW, different person (vary the face naturally) - keep only "
              "the style, framing, lighting, skin condition and quality level of "
              "the reference. Vary small background details slightly.")
    gen_prompt = ("Use the reference image ONLY for pose, framing, composition, "
                  f"lighting and overall vibe. {person}\n\n{p0}")

    print("generate candidate A ...")
    a = call(IMAGE_MODEL, [img_part(ref0), {"text": gen_prompt}], True, key)
    print("generate candidate B ...")
    b = call(IMAGE_MODEL, [img_part(ref0), {"text": gen_prompt}], True, key)

    verdict = text_call([img_part(a), img_part(b), {"text":
        "Two candidate photos. Which one looks MORE like a real, unedited, "
        "amateur iPhone front-camera photo (natural grain, imperfect framing, "
        "believable skin texture, no AI look)? Answer with exactly one letter: "
        "A or B."}], key)
    winner = a if verdict.strip().upper().startswith("A") else b
    print(f"judge: {verdict.strip()[:40]} -> {'A' if winner is a else 'B'}")
    open(f"{out}/akne.jpg", "wb").write(winner)

    edit_prompt = ("The first input image shows the person - keep their IDENTITY "
                   "exactly (same face, same hair, same distinguishing marks), but "
                   "on a different day, two weeks later, and their skin is now fully "
                   "healed: clear and calm with realistic pores and subtle natural "
                   "texture preserved, no acne, no bumps, no redness, not airbrushed, "
                   "only one or two barely-visible faint marks. The second input "
                   "image is ONLY a reference for the new pose, framing, clothing "
                   "style, background and lighting.\n\n" + p14)
    print("generate day-14 edit ...")
    clear = call(IMAGE_MODEL, [img_part(winner), img_part(ref14),
                               {"text": edit_prompt}], True, key)
    open(f"{out}/clear.jpg", "wb").write(clear)
    print(f"Fertig: {out}/akne.jpg + {out}/clear.jpg")


if __name__ == "__main__":
    main()
