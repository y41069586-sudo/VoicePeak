# Display font — Playfair Display (SIL OFL)

The design system (`VType`, DESIGN_SPEC §3) uses **Playfair Display** for hero
moments and big numerals. The font files are **not committed** — drop them here.

## What to add (exact filenames — they're already registered in Info.plist)
- `PlayfairDisplay-Italic.ttf`  → hero titles, section titles
- `PlayfairDisplay-Regular.ttf` → available for large regular display use
- `PlayfairDisplay-Medium.ttf`  → big score numerals (ScoreRing, reveals)
- `LICENSE.txt` (the SIL OFL license text that ships with Playfair Display)

Get them from Google Fonts (SIL OFL) — confirm the license permits app embedding.

## PostScript names
`VType` calls `Font.custom("PlayfairDisplay-Italic" / "-Regular" / "-Medium", …)`.
If your files expose different PostScript names, adjust the strings in
`DesignSystem/VType.swift`.

Until the files are present, every display style falls back to an italic/regular
**system serif** — legible, no tofu, just not the bespoke face.
