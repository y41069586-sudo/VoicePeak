#!/usr/bin/env python3
"""
Apify export → leads.csv adapter.

Takes a CSV you exported from an Apify actor (Instagram/TikTok/YouTube profile
scraper) and turns it into the leads.csv format generate_emails.py expects:
extracts a contact email from the bio/description text, keeps only creators in
your target band, ranks by engagement, and merges everything into one file.

It reads data YOU gathered — it does not fetch or scrape anything itself.

Usage:
    python3 import_apify.py apify_export.csv --platform instagram \
        --min-followers 10000 --max-followers 80000 --out leads.csv

The actor's column names vary, so this maps the common ones automatically and
you can override with --map. Run with --show-columns first to see what your
export actually contains:

    python3 import_apify.py apify_export.csv --show-columns
"""

import csv
import re
import sys
import argparse

EMAIL_RE = re.compile(r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}")

# Common Apify column names → our canonical fields. First match wins.
DEFAULT_MAP = {
    "handle":    ["username", "ownerUsername", "handle", "profileName", "channelName", "name"],
    "name":      ["fullName", "displayName", "title", "name"],
    "followers": ["followersCount", "followers", "followerCount", "subscriberCount", "edge_followed_by"],
    "bio":       ["biography", "bio", "description", "renderedDescription", "signature", "about"],
    "email":     ["email", "publicEmail", "businessEmail", "contactEmail"],
    "likes":     ["avgLikes", "averageLikes", "likesCount", "avgEngagement", "edge_liked_by"],
    "posts":     ["postsCount", "videoCount", "mediaCount", "edge_owner_to_timeline_media"],
}


def build_getter(header, overrides):
    """Return field->column resolver against the actual export header."""
    lower = {h.lower(): h for h in header}
    resolved = {}
    for field, candidates in DEFAULT_MAP.items():
        col = overrides.get(field)
        if not col:
            for c in candidates:
                if c.lower() in lower:
                    col = lower[c.lower()]
                    break
        resolved[field] = col
    return resolved


def num(v):
    """Parse '12.5k' / '1,234' / '2M' style follower counts."""
    if v is None:
        return 0
    s = str(v).strip().lower().replace(",", "").replace(" ", "")
    if not s:
        return 0
    mult = 1
    if s.endswith("k"):
        mult, s = 1_000, s[:-1]
    elif s.endswith("m"):
        mult, s = 1_000_000, s[:-1]
    try:
        return int(float(s) * mult)
    except ValueError:
        return 0


def email_from(row, cols):
    if cols["email"] and row.get(cols["email"], "").strip():
        return row[cols["email"]].strip()
    bio = row.get(cols["bio"] or "", "") or ""
    m = EMAIL_RE.search(bio)
    return m.group(0) if m else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("export", help="CSV exported from Apify")
    ap.add_argument("--platform", default="instagram")
    ap.add_argument("--min-followers", type=int, default=5000)
    ap.add_argument("--max-followers", type=int, default=200000)
    ap.add_argument("--niche", default="skincare")
    ap.add_argument("--out", default="leads.csv")
    ap.add_argument("--emails-only", action="store_true",
                    help="drop creators with no email found")
    ap.add_argument("--show-columns", action="store_true")
    ap.add_argument("--map", action="append", default=[],
                    help="override a column, e.g. --map followers=fans")
    args = ap.parse_args()

    with open(args.export, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        header = reader.fieldnames or []
        rows = list(reader)

    if args.show_columns:
        print("Columns in export:")
        for h in header:
            print(f"  {h}")
        return

    overrides = dict(kv.split("=", 1) for kv in args.map)
    cols = build_getter(header, overrides)
    missing = [f for f in ("handle", "followers") if not cols[f]]
    if missing:
        sys.exit(f"Couldn't find columns for {missing}. "
                 f"Run --show-columns and pass --map field=Column.")

    out_cols = ["email", "first_name", "handle", "platform", "followers",
                "avg_likes", "niche", "hook"]
    kept, no_email, out_of_band = [], 0, 0

    for row in rows:
        followers = num(row.get(cols["followers"], 0))
        if not (args.min_followers <= followers <= args.max_followers):
            out_of_band += 1
            continue
        email = email_from(row, cols)
        if not email and args.emails_only:
            no_email += 1
            continue
        handle = (row.get(cols["handle"], "") or "").strip().lstrip("@")
        name = (row.get(cols["name"] or "", "") or "").strip()
        first = name.split()[0] if name else ""
        likes = num(row.get(cols["likes"] or "", 0))
        kept.append({
            "email": email,
            "first_name": first,
            "handle": "@" + handle if handle else "",
            "platform": args.platform,
            "followers": followers,
            "avg_likes": likes,
            "niche": args.niche,
            "hook": "",  # add a real one per row before sending
        })

    kept.sort(key=lambda r: (r["avg_likes"] / r["followers"]) if r["followers"] else 0,
              reverse=True)

    with open(args.out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=out_cols)
        w.writeheader()
        w.writerows(kept)

    with_email = sum(1 for r in kept if r["email"])
    print(f"✓ {len(kept)} creators → {args.out}")
    print(f"  {with_email}/{len(kept)} have an email "
          f"(fill the rest manually from their link-in-bio)")
    print(f"  skipped: {out_of_band} out of follower band"
          + (f", {no_email} without email" if args.emails_only else ""))
    print("  Next: add a personal `hook` per row, then run generate_emails.py.")


if __name__ == "__main__":
    main()
