# Display font — Playfair Display (SIL OFL) — **bundled**

The design system (`VType`, DESIGN_SPEC §3) uses **Playfair Display** for hero
moments and big numerals. The font files are now **committed** here.

## What's here
- `PlayfairDisplay.ttf` — upright **variable** font (`wght` 400–900)
- `PlayfairDisplay-Italic.ttf` — italic **variable** font (`wght` 400–900)
- `OFL.txt` — the SIL Open Font License these ship under

Both files expose the family name **"Playfair Display"**. `VType` loads that
family and selects weight via the variable `wght` axis (`.weight(…)`) and the
italic face via `.italic()`. They're registered in `Resources/Info.plist`
(`UIAppFonts`) and bundled automatically by XcodeGen.

## Source & license
Downloaded from Google Fonts' `google/fonts` repo (`ofl/playfairdisplay`).
SIL Open Font License 1.1 — embedding in an app is permitted. Keep `OFL.txt`
alongside the fonts.

## If you swap the files
`VType` references only the family name `"Playfair Display"`, so any TTF/OTF that
reports that family name works. If you replace them with a differently-named
family, update `private static let playfair` in `DesignSystem/VType.swift`.
If the family is ever missing at runtime, every display style falls back to the
system serif — legible, no tofu.
