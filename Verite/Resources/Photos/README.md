# Onboarding photos

Drop the three onboarding photos here as **loose image files** (JPG/PNG/HEIC),
named exactly:

- `GlowHero.jpg`     — opening + sign-in screen (3:4 portrait)
- `GlowTexture.jpg`  — first insight screen (3:4 portrait)
- `GlowRitual.jpg`   — second insight screen (3:4 portrait)

No `Contents.json` and no asset-catalog entry needed — `RampPhoto` loads them
from the bundle by name (`RampPhoto.load`). Until a file is present its screen
shows a warm gradient placeholder, so the build is always green.

(`.md` files are excluded from the build target, so this note never ships.)

---

# Still missing: the intro carousel and the acne picker

Eight files, two very different jobs. Both screens already work without them —
the intro falls back to its line-art and the acne tiles to a placeholder — so
neither blocks a build.

## Intro carousel — four product screenshots

`RampBootScreen`. Drawn with `scaledToFit` at up to 340pt tall and full width
inside the page margins, with **no card, shadow or frame added** — whatever
composition the file carries is what shows. Roughly square, so supply at least
**1200 × 1200 px**.

Each image has to earn the sentence printed under it:

| File | Headline it sits under | What it must show |
|---|---|---|
| `IntroScore` | "The honest way to clear your skin." | The results screen with the 0–100 score visible |
| `IntroScan` | "See what's driving your breakouts." | The capture screen mid-scan, mesh over the face |
| `IntroRoutine` | "A routine built around your skin." | The routine screen, morning and evening steps |
| `IntroProgress` | "Watch it change over 14 days." | The progress or comparison view across scans |

Two dependencies worth knowing before you start:

1. **These need a working build first.** They are screenshots of screens that
   have to run before they can be captured.
2. **Capture them after the palette change.** Older screenshots still show the
   teal accent and would put the wrong-coloured app on the first screen the
   user ever sees.

## Acne picker — four macro skin photos

`RampAcneTypeScreen`. Two-column tiles drawn with `scaledToFill` at
**150 × 116pt**, so roughly **1.3 : 1** and cropped to fill — centre the
lesion or the crop eats it. Supply at least **600 × 460 px**.

| File | Tile label | Caption | Subject |
|---|---|---|---|
| `AcneBlackheads` | Blackheads | Open, dark pores | Open comedones |
| `AcneWhiteheads` | Whiteheads | Small closed bumps | Closed comedones |
| `AcnePapules` | Red bumps | Sore, no head | Inflamed papules |
| `AcneCysts` | Deep, painful | Under the skin | Nodules / cystic |

**The rule these four live under: macro crops of skin, nobody identifiable.**
No eyes, no jawline, no tattoo, no background. It is not a style preference.
Showing a recognisable person as having a skin condition is what the stock
libraries call "sensitive use", and it sits behind a separate licence that a
standard purchase does not include — a face here breaches the licence we
bought before anyone even complains. Cropped to skin, none of it attaches.

Licensing: a one-month Shutterstock or Adobe Stock plan (~$45 / ~$30) covers
this, and the licences stay valid after cancelling. Buy eight candidates for
the four slots so the ones that read badly at tile size can be swapped.

**Do not use DermNet's free images.** They are the first result for every acne
search and look the most clinical, and they are CC BY-NC-ND: NonCommercial
rules out a paid app, and NoDerivatives independently forbids the cropping
these tiles need.

**Do not use the ACNE04 research dataset.** It is the only free source with
the right subject, which makes it the most tempting — and it is 1,457
identifiable faces with no documented provenance and no commercial licence.
