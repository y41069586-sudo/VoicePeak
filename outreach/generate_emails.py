#!/usr/bin/env python3
"""
Glowé creator cold-email generator.

Reads a leads CSV, scores each creator by fit, fills a personalized 3-step
email sequence, and writes an import-ready CSV for a cold-email tool
(Instantly / Smartlead / Lemlist). It does NOT send anything — sending goes
through a real tool that handles domain warm-up + deliverability, so mails
land in the inbox and you stay compliant.

Usage:
    python3 generate_emails.py leads.csv
    python3 generate_emails.py leads.csv --out outreach_ready.csv

leads.csv columns (see leads.example.csv):
    email, first_name, handle, platform, followers, avg_likes, niche, hook
    - hook is an optional 1-line personal reference; if empty a niche default
      is used, but a real hook roughly triples reply rates — fill it in.
"""

import csv
import sys
import argparse

# ---- Sender identity (EDIT THESE — required for legal cold email) ----------
FROM_NAME   = "Glowé Team"
SENDER_LINE = "Doaa & the Glowé team"
# CAN-SPAM / GDPR: a real postal address + a working opt-out are mandatory.
COMPANY_ADDRESS = "Glowé · Wilhelm-Diess-Weg 3a · 94081 Fürstenzell · Germany"
UNSUB_LINE = "Not your thing? Just reply \"stop\" and we won't message again."

# ---- The sequence ----------------------------------------------------------
SUBJECTS = {
    1: "Paid collab with Glowé, {first_name}?",
    2: "Quick one, {first_name} 👀",
    3: "Last note from Glowé, {first_name}",
}

EMAIL_1 = """Hey {first_name},

{hook_sentence}

We're the founders of Glowé — an app that scans your skin, gives an honest
0–100 score and a personalized 14-day glow-up plan (plus an AI "you as a 10/10"
preview). Super visual, made for {niche} content.

We'd love to do a paid collab with you. Your audience is exactly who we built
this for.

Interested? Happy to send you free lifetime access to try it first.

— {sender}

{unsub}
{address}"""

EMAIL_2 = """Hey {first_name},

Just floating this back up — still keen to set up a paid collab with you for
Glowé. Takes 2 minutes to try (I'll send free access), and it makes for a
really clean before/after piece of content.

Worth a quick chat?

— {sender}

{unsub}
{address}"""

EMAIL_3 = """Hey {first_name},

Last one from me, promise. If a paid Glowé collab could be a fit — even later
this year — just reply and I'll send over the details + free access. If not,
all good, I'll leave you be.

— {sender}

{unsub}
{address}"""

NICHE_HOOKS = {
    "skincare": "Your skincare content is exactly the honest, no-BS style we love.",
    "beauty":   "Your beauty content stood out to us — real and genuinely helpful.",
    "":         "Came across your profile and really liked your content.",
}


def hook_sentence(row):
    h = (row.get("hook") or "").strip()
    if h:
        # Capitalize + ensure it ends cleanly.
        s = h[0].upper() + h[1:]
        return s if s.endswith((".", "!", "?")) else s + "."
    return NICHE_HOOKS.get((row.get("niche") or "").strip().lower(), NICHE_HOOKS[""])


def fit_score(row):
    """Engagement rate as the core signal (avg_likes / followers). Micro
    creators (10k–80k) with >3% engagement are usually the best ROI."""
    try:
        followers = float(row.get("followers") or 0)
        likes = float(row.get("avg_likes") or 0)
        if followers <= 0:
            return None
        er = likes / followers
        return round(er * 100, 1)  # percent
    except (TypeError, ValueError):
        return None


def render(row):
    ctx = {
        "first_name": (row.get("first_name") or "there").strip() or "there",
        "niche": (row.get("niche") or "skincare").strip() or "skincare",
        "hook_sentence": hook_sentence(row),
        "sender": SENDER_LINE,
        "unsub": UNSUB_LINE,
        "address": COMPANY_ADDRESS,
    }
    return {
        "subject_1": SUBJECTS[1].format(**ctx),
        "body_1": EMAIL_1.format(**ctx),
        "subject_2": SUBJECTS[2].format(**ctx),
        "body_2": EMAIL_2.format(**ctx),
        "subject_3": SUBJECTS[3].format(**ctx),
        "body_3": EMAIL_3.format(**ctx),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("leads", help="input CSV")
    ap.add_argument("--out", default="outreach_ready.csv")
    args = ap.parse_args()

    with open(args.leads, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    out_cols = ["email", "first_name", "handle", "platform", "followers",
                "engagement_pct", "subject_1", "body_1", "subject_2", "body_2",
                "subject_3", "body_3"]

    ranked = []
    with open(args.out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=out_cols)
        w.writeheader()
        for row in rows:
            email = (row.get("email") or "").strip()
            if not email or "@" not in email:
                continue  # skip leads without a real address
            er = fit_score(row)
            emails = render(row)
            w.writerow({
                "email": email,
                "first_name": (row.get("first_name") or "").strip(),
                "handle": (row.get("handle") or "").strip(),
                "platform": (row.get("platform") or "").strip(),
                "followers": (row.get("followers") or "").strip(),
                "engagement_pct": er if er is not None else "",
                **emails,
            })
            ranked.append((er if er is not None else -1,
                           row.get("handle") or email,
                           (row.get("hook") or "").strip() != ""))

    total = len(ranked)
    with_hook = sum(1 for _, _, h in ranked if h)
    print(f"✓ {total} leads → {args.out}")
    if total:
        print(f"  {with_hook}/{total} have a personal hook "
              f"({'good' if with_hook == total else 'add hooks to the rest for ~3x replies'})")
        print("\nTop fits by engagement:")
        for er, who, _ in sorted(ranked, reverse=True)[:10]:
            print(f"  {who:<24} {er if er >= 0 else '?':>5}% engagement")


if __name__ == "__main__":
    main()
