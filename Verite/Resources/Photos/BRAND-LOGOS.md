# Brand logo provenance

Where each mark in `RampBrandScreen` came from, and under what terms. Keep
this current: if a complaint ever arrives under App Store Review guideline
5.2.1, the first thing asked for is where the file came from and on what
basis it is used. A sourcing record you wrote afterwards is worth much less
than one you kept.

Drop files here as `Brand<Name>.png` (transparent) or import the SVG into the
asset catalog — Xcode has accepted SVG since Xcode 12 (Single Scale +
Preserve Vector Data, back to iOS 13), and `RampPhoto.load` checks the asset
catalog before this folder. Missing files degrade to a monogram, so a partial
set ships fine.

## Two things that are easy to get wrong

**`PD-textlogo` is a copyright tag, not permission.** It means Wikimedia
considers the mark too simple to attract copyright — the file is free to
copy. Trademark is an entirely separate regime and is the one that governs
showing a mark to identify a product. The tag makes the download clean; it
says nothing about the use. (Same shape as the acne photos, where the
copyright licence and the personality rights were two independent questions.)

**A CC BY-SA tag on a corporate logo is usually a stranger's mistake.** It
means some uploader ticked "own work" on a mark they do not own. It is not a
grant from the brand, and such files get retagged or deleted from Commons
routinely. Do not build on one.

## Status

| Brand | Source | Format | Licence tag | Notes |
|---|---|---|---|---|
| CeraVe | [Commons](https://commons.wikimedia.org/wiki/File:CeraVe_logo.png) | PNG 1230×466 | `PD-textlogo` | Ready to use as-is |
| La Roche-Posay | [Commons](https://commons.wikimedia.org/wiki/File:La_Roche-Posay_(brand).svg) | SVG 284×122 | `PD-textlogo` | Also an `(orangebrand)` variant — check current packaging |
| Neutrogena | [Commons](https://commons.wikimedia.org/wiki/File:Neutrogena_logo.svg) | SVG 512×113 | `PD-textlogo` | |
| NIVEA | [Commons](https://commons.wikimedia.org/wiki/File:Nivea_logo.svg) | SVG 50×50 | `PD-textlogo` | **Take the plain wordmark, not the blue disc** — see below |
| Eucerin | [Commons](https://commons.wikimedia.org/wiki/File:Eucerin_logo.svg) | SVG 90×37 | `PD-textlogo` | Tag reported, verify on the page |
| Bioderma | [Commons](https://commons.wikimedia.org/wiki/File:Bioderma_logo.svg) | SVG 232×47 | `PD-textlogo` | |
| Cetaphil | [Galderma downloads](https://www.galderma.com/us/downloads) | PNG/JPG | not stated | The Commons file is **CC BY-SA** *and* a Thailand variant — avoid it |
| The Ordinary | [DECIEM](https://deciem.com/en-us/theordinary-logo.html) | unknown | none | No Commons file and no Wikipedia article exist |
| Avène | [Commons](https://commons.wikimedia.org/wiki/File:Av_new-logo-2022_eau-thermale-avene.png) | PNG | CC BY-SA (user-applied) | Pierre Fabre's press site needs journalist credentials |
| Vichy | [Commons](https://commons.wikimedia.org/wiki/File:Vichy_Laboratoires_(logo).jpg) | JPEG 1920×615 | **unknown** | JPEG has no alpha — poor starting point |
| Paula's Choice | [Unilever media assets](https://www.unilever.com/news/press-and-media/media-assets/) | unknown | unclear | Ask `Press-Office.London@Unilever.com`; nothing on Commons |
| COSRX | — | — | — | Nothing on Commons, no press kit found. Amorepacific has owned it since Oct 2023 |

All rows above are search-derived — every one of these pages refused a direct
fetch from the build environment. Confirm the licence tag by eye on the file
page before relying on it; it takes five seconds each.

## NIVEA: take the wordmark, not the disc

Beiersdorf holds a registered abstract colour mark on NIVEA blue (Pantone
280C). Unilever tried to cancel it and failed — BGH, 9 July 2015, I ZB 65/13
"Nivea-Blau" — and the mark stands. The plain wordmark engages one right; the
blue-disc lockup engages the word mark and the colour mark together. Prefer
`File:Nivea_logo.svg` over `File:NIVEA_logo_2021.svg`.

## Beiersdorf's newsroom does not cover this app

`beiersdorf.com/newsroom/media-downloads` grants use "exclusively for
editorial and non-commercial purposes." That excludes a paid app whatever the
app's purpose, so NIVEA and Eucerin should come from Commons instead. Noted
here so nobody re-discovers the newsroom in six months and assumes it is the
better source because it is official.

## Getting a PNG without installing anything

Wikimedia renders any SVG to a transparent PNG at a width you name:

    https://commons.wikimedia.org/wiki/Special:FilePath/Bioderma_logo.svg?width=512

## If you do rasterise locally — the trap worth knowing

An SVG containing live `<text>` does not carry its font. The renderer looks it
up on your machine, and when it is missing it substitutes silently: you get a
valid-looking PNG with the wordmark set in the wrong typeface, which for a
logo means the whole asset is wrong. It fails quietly, so you may not catch it
until it ships. Check first:

    grep -c "<text" logo.svg        # 0 is what you want

If it is non-zero, convert the text to outlines before rendering:

    inkscape logo.svg --export-type=svg --export-text-to-path \
      --export-filename=logo-paths.svg

Then render with `rsvg-convert -w 336 -b none logo-paths.svg -o out@2x.png`.
Do not rasterise with ImageMagick alone — without a librsvg or Inkscape
delegate it silently falls back to its own renderer and gets SVGs subtly
wrong. Pad rather than stretch: these marks are 3:1 or wider and the row's
box is 1.4:1, so fit inside and fill the rest with transparency.
