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

# Still missing: the acne picker

Four macro skin photos. The screen already works without them — the tiles fall
back to a placeholder — so this does not block a build.

The intro carousel used to be listed here too, waiting on four product
screenshots (`IntroScore`, `IntroScan`, `IntroRoutine`, `IntroProgress`). It no
longer needs them. `RampIntroArt` now draws real iPhones in SwiftUI with the
app's own screens running live inside them (`RampDeviceMockup.swift`,
`RampIntroScreens.swift`, `RampFaceMesh.swift`), which removes the two
dependencies that made those files hard to produce: they needed a working build
to capture, and they needed re-capturing after every palette change. Live
screens have neither problem.

One image the carousel does use: `SampleFace`, already committed here. It is the
portrait the scan mockup lays its mesh over, and the avatar on the results
mockup. If it is ever swapped, re-measure `RampIntroScanScreen.faceRect` — the
comment there says which two landmarks to read off.

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
| `AcneScars` | Marks & scars | Left behind after healing | Post-acne marks and atrophic scarring |

There is a sixth tile, "Not sure", which has no photograph — it draws a
question mark and clears every other selection when picked. Continue stays
disabled until something is chosen, so without that opt-out an uncertain user
is stuck on the second screen of the flow.

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
