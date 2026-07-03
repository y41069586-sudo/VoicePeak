# Display font drop location

The "Aesthetic Blue" look uses an elegant editorial serif for headlines and big
numbers. It is intentionally **not committed** — font licensing travels with the
shipping developer.

## To bundle the display font

1. Download an **SIL OFL** face that permits app embedding — recommended:
   **Playfair Display Italic** (or Cormorant / Marcellus).
2. Drop the `.ttf` / `.otf` here (`Verite/Resources/Fonts/`).
3. Add a `UIAppFonts` array to `Verite/Resources/Info.plist` listing the file name(s).
4. Confirm the PostScript name matches `Typography.displayFontName`
   (default `"PlayfairDisplay-Italic"`) — update that constant if you chose another face.

Until a font is added, `Typography` falls back to the **system serif** — the app
renders correctly and legibly, just without the custom face. See
`docs/DESIGN_SPEC.md` for the font-usage rules.
