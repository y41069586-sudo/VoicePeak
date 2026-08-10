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
