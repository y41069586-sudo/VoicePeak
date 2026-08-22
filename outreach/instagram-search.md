# Instagram creator search — SkinFix playbook

No legal bulk API exists for Instagram, but manual search with a system is
fast: ~20 quality leads in 30 minutes once you're warm. Target: 150 leads in
~8 days → feeds `leads.csv` → email sequence.

## Who you're looking for (filter in 10 seconds)

- **10k–80k followers** (micro: best engagement, cheapest, most responsive)
- **Face on camera** (skin visible — they can actually demo a skin scan)
- **Reels ≥ every few days** (active = reach)
- **Engagement >3%**: avg likes on last 5 reels ÷ followers. 40k followers →
  want 1.2k+ likes. Below 1% = bought followers, skip.
- **Email reachable**: "E-Mail" button on profile, email in bio, or
  link-in-bio (Linktree/Beacons → "business inquiries")
- Language: DE creators first (your first market), then EN

## Search terms (type into IG search → tab "Accounts" AND "Reels")

**German (first priority):**
- `skincare routine deutsch`
- `hautpflege routine`
- `hautpflege tipps`
- `akne tipps` / `akne journey`
- `glow up routine`
- `skincare unter 20€` (price-content creators love app collabs)
- `drogerie skincare` (drugstore reviewers = honest-review niche, perfect fit)
- `hautarzt erklärt` (adjacent: derm-education audience)

**English (second wave):**
- `skincare routine honest`
- `acne journey` / `acne transformation`
- `glow up challenge`
- `skin rating` / `rate my skincare`
- `skincare over 30` (older segment, matches your age-band targeting)

**Hashtag ladder** (open a hashtag → "Reels" tab → sort by recent, skip
mega-accounts): `#hautpflegeroutine` `#skincaredeutschland` `#aknehilfe`
`#glowuptipps` `#hautpflegetipps` — prefer hashtags with **50k–500k posts**
(big enough to be alive, small enough that micros rank).

## The 3 multiplier tricks (where the volume really comes from)

1. **Similar-accounts chevron:** on any good creator's profile, tap the "+"
   /chevron next to Follow → IG shows 10–20 lookalike accounts. One good find
   becomes ten. This is the single fastest method — chain it.
2. **Comment mining:** open a viral skincare reel → the top commenters with
   face avatars and creator-looking handles are often smaller creators in the
   same niche. They're also the ones most likely to reply to outreach.
3. **Audio mining:** on a trending skincare reel, tap the audio → every reel
   using that sound → sorted by reach, full of niche creators you won't find
   via hashtags.

## Grabbing the email (per profile, ~20 seconds)

1. Profile → **"E-Mail" button** (business accounts) → that's the address.
2. No button → **bio text** (many write "PR: name@…").
3. Linktree/Beacons in bio → open → "business" / "contact" entry.
4. Nothing? Check their **TikTok/YouTube** (same handle) — YouTube About page
   or channel description often has it (your `find_youtube.py` catches these).
5. Still nothing → skip. Don't DM-pitch cold; IG filters it like TikTok does.

## Daily workflow (30–40 min → 20 leads)

1. Pick ONE search term or one seed creator → chain similar-accounts.
2. For each candidate: 10-second filter (followers, face, reels, ER).
3. Passes → grab email + note ONE genuine hook ("her 3-step barrier reel")
   into `leads.csv` (`hook` column — this is what triples replies).
4. 20 leads/day × 8 days = 160 → run `generate_emails.py` → import to the
   sending tool in weekly batches.

## Log columns (leads.csv, already the right format)

`email, first_name, handle, platform=instagram, followers, avg_likes
(avg of last 5 reels), niche, hook`
