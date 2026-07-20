# Glowé creator outreach — cold email system

Legal, scalable creator outreach. You collect leads into a CSV; the generator
scores each creator and produces a personalized 3-email sequence, import-ready
for a proper sending tool. **Nothing is sent from here** — sending goes through
a tool that handles domain warm-up and deliverability (that's what keeps you out
of spam and out of trouble).

## Why not just blast from a script / IG bot?
- IG/TikTok DM bots violate their ToS → shadowban/permanent ban. Not worth it on
  a founder account.
- Cold email is fine **if** you do deliverability right. Blasting from your main
  domain via a raw SMTP script burns that domain in days. The tool below exists
  to prevent exactly that.

## One-time setup (do this before sending a single email)

1. **Separate sending domain.** Don't send cold mail from `glowe.app`. Buy a
   look-alike, e.g. `getglowe.com` or `glowe-app.com`, and send from that. If it
   ever gets flagged, your main domain is untouched.
2. **Mailboxes + auth.** Create 1–3 mailboxes on the sending domain
   (hello@, team@). Set up **SPF, DKIM, DMARC** (the tool guides you). Without
   these, you go straight to spam.
3. **Warm-up (2–3 weeks).** Turn on the tool's warm-up feature before real
   sending. Ramp volume slowly: ~20/day/mailbox week 1, up to ~40–50 later.
   Never dump hundreds on day one.
4. **Pick a tool.** Instantly.ai or Smartlead (both: warm-up + sequences +
   inbox rotation, ~€30–50/mo). Lemlist/Apollo also work.

## Finding creators (per platform)

- **YouTube — automated & legal.** `find_youtube.py` uses the official Data
  API to search a niche, pull real stats, and extract emails from channel
  descriptions:
  ```bash
  export YOUTUBE_API_KEY="your-key"      # free, console.cloud.google.com
  python3 find_youtube.py "skincare routine" "acne tips" "glow up" \
      --min-subs 10000 --max-subs 300000 --out leads.csv
  ```
  Output is already in the `leads.csv` format — add a `hook` per row and run
  `generate_emails.py`.
- **TikTok / Instagram via an Apify export.** If you run a profile scraper in
  the Apify console yourself and export a CSV, `import_apify.py` turns it into
  `leads.csv`: it extracts emails from the bio text, filters to your follower
  band, and ranks by engagement.
  ```bash
  python3 import_apify.py apify_export.csv --show-columns   # see the columns first
  python3 import_apify.py apify_export.csv --platform instagram \
      --min-followers 10000 --max-followers 80000 --out leads.csv
  ```
  (Note: scraping TikTok/IG is against their ToS and mass-emailing scraped
  personal addresses is legally restricted for a German company — see the
  compliance section. The clean bulk route stays Creator Marketplace or a
  licensed provider like EnsembleData/Modash.)
- **Instagram — manual.** Collect handles + business emails from bio /
  link-in-bio, or via the same paid providers. No official bulk read.

## Daily workflow

1. **Find creators** (skincare/beauty micro-influencers, ~10k–150k, engagement
   >3%) using the sources above. Grab their **business email**.
2. **Fill `leads.csv`** — see `leads.example.csv`. One line per creator. Add a
   real `hook` (one thing you genuinely liked) — it roughly **triples** replies.
3. **Generate:**
   ```bash
   python3 generate_emails.py leads.csv --out outreach_ready.csv
   ```
   It prints a fit ranking (by engagement) and writes `outreach_ready.csv`.
4. **Import `outreach_ready.csv`** into Instantly/Smartlead as a sequence
   (Email 1 = day 0, Email 2 = day 3, Email 3 = day 7). Map the columns; the
   tool auto-stops the sequence when someone replies.
5. **Track replies** and move deals to a simple pipeline (or the Sheets tracker
   — ask and I'll build it).

## Legal / compliance (read once)

- **B2B cold email is allowed** in the EU (GDPR legitimate interest) and US
  (CAN-SPAM), **if**: you have a real reason to contact them (they're a
  professional creator), every email has a **working opt-out**, and your **real
  postal identity** is included. Both are baked into the templates — edit the
  constants at the top of `generate_emails.py`:
  - `SENDER_LINE`, `COMPANY_ADDRESS`, `UNSUB_LINE`.
- Honor every "stop"/unsubscribe immediately. The tool tracks this automatically.
- Don't buy scraped email lists; collect from public business contacts.

## Files

- `leads.example.csv` — the input format (copy to `leads.csv` and fill).
- `generate_emails.py` — scorer + personalizer → `outreach_ready.csv`.
- `outreach_ready.example.csv` — example output (safe to delete).

## Tuning

- Edit the sequence copy (subjects + bodies) directly in `generate_emails.py`.
- The "free lifetime access" offer in Email 1 is the highest-converting hook for
  creators — keep it. Add an affiliate/revenue-share line once your affiliate
  flow is live.
