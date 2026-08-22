# Onboarding intro — preview renders

The four opening carousel pages (`RampBootScreen`), rendered so they can be
looked at without opening Xcode.

| File | What it shows |
|---|---|
| `page-1.jpg` | "The honest way to clear your skin." — trio, results screen forward |
| `page-2.jpg` | "See what's driving your breakouts." — one phone, the scan mid-read |
| `page-3.jpg` | "A routine built around your skin." — trio, routine forward |
| `page-4.jpg` | "Watch it change over 14 days." — trio, evolution forward |
| `scan.jpg` | The capture screen on its own, full size, mesh over the face |

Regenerate with:

```
npm i playwright
node docs/onboarding-preview/render.js
```

`preview.html` loads the portrait straight from
`Verite/Resources/Photos/SampleFace.jpg` — the same file the app uses — so
there is no second copy to keep in step.

---

## Read this before you trust it

**`preview.html` is a PORT of the SwiftUI, not the SwiftUI.** It re-implements
the mesh geometry, the device frame and the four screens in HTML and canvas so
that a machine without a Swift toolchain can still show what the opening looks
like. It is a viewing aid. It is not a test.

That means it can drift. Nothing enforces that the JS matches the Swift — if
you change one and not the other, these renders quietly start lying, and they
lie most convincingly about the thing hardest to check by eye: where the mesh
sits on the face.

The pieces that exist twice, and have to be changed twice:

| Swift | Ported into `preview.html` |
|---|---|
| `RampFaceMeshGeometry` — `profile`, `vertex`, every contour | `PROFILE`, `vertex()`, `eye/brow/NOSE_*/LIP_*` |
| `RampFaceMesh` — the draw passes and their opacities | `drawMesh()` |
| `RampPhoneFrame` — bezel, radii, island, buttons | `phone()` |
| `RampPhoneTrio` — scale, rotation, offsets | `trio()` |
| `RampIntroScreens` — all four screens | `homeScreen()` / `scanScreen()` / `routineScreen()` / `progressScreen()` |
| `RampIntroScanScreen.faceRect` | `FACE_RECT` |

Two things the renders get wrong even when the port is in step:

- **Type.** Liberation Sans stands in for SF Pro, and the SF Symbols are
  redrawn as SVG. Weights and metrics are close, not identical.
- **Compositing.** These are Chromium pixels, not Core Animation's. Shadows,
  blurs and sub-pixel antialiasing differ.

So: use this to check layout, balance, palette and mesh placement. Use a real
build to check anything else.

## Re-measuring the face box

If `SampleFace.jpg` is ever swapped, the mesh has to be re-aimed. It is a
two-landmark job, because the mesh model is anchored on two things it can find
on any frontal portrait:

- the **pupil line**, which the model puts at `v = 0.39`
- the **bottom of the chin**, at `v = 1.0`

Read both off the new photo as fractions of the 402 × 874pt screen, then solve
for the box top `t` and height `h`:

```
t + 0.39h = pupilLine
t +     h = chin
```

Width follows from the pupils too: the model puts them 0.52 half-widths out
from the midline, so `halfWidth = pupilOffset / 0.52`.

Set the result on `RampIntroScanScreen.faceRect` **and** on `FACE_RECT` in
`preview.html`. Then run `render.js` and check `scan.jpg` — brows on brows,
eye contours around eyes, lip outline on lips, mesh bottom at the chin.
