#!/usr/bin/env python3
"""
Glowé YouTube creator finder (official Data API v3 — legal, no scraping).

Searches YouTube for creators in a niche, pulls real channel stats, extracts a
business email from the channel description where present, scores by fit, and
writes a leads CSV in the exact format generate_emails.py expects.

Setup (one-time, free):
    1. console.cloud.google.com → new project → enable "YouTube Data API v3".
    2. Create an API key. Then:
       export YOUTUBE_API_KEY="your-key"

Usage:
    python3 find_youtube.py "skincare routine" "acne tips" "glow up" \
        --min-subs 10000 --max-subs 300000 --out leads.csv

Notes:
    - The API does NOT expose the hidden "business email" (the one behind the
      CAPTCHA on the About page). It DOES return the channel description, where
      many creators paste a contact/booking email — that's what we extract.
      Channels without a found email are still written (email blank) so you can
      fill it manually from their link-in-bio.
    - "avg_likes" is filled with lifetime avg views/video (a YouTube fit proxy),
      so generate_emails.py's engagement ranking still works. Relabel in your
      head as "avg views".
    - Quota: each keyword = 1 search (100 units) + 1 channels lookup (~1 unit).
      Default free quota (10,000/day) ≈ ~90 keywords/day. Plenty.
"""

import csv
import os
import re
import sys
import json
import argparse
import urllib.parse
import urllib.request

API = "https://www.googleapis.com/youtube/v3"
EMAIL_RE = re.compile(r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}")


def _get(path, params):
    params = {**params, "key": os.environ["YOUTUBE_API_KEY"]}
    url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.load(r)


def search_channels(query, limit=50):
    """Channel IDs matching a niche keyword."""
    data = _get("search", {
        "part": "snippet", "type": "channel", "q": query,
        "maxResults": min(limit, 50), "relevanceLanguage": "en",
    })
    return [it["snippet"]["channelId"] for it in data.get("items", [])]


def channel_details(channel_ids):
    """Stats + snippet for up to 50 channels in one call."""
    if not channel_ids:
        return []
    data = _get("channels", {
        "part": "snippet,statistics,brandingSettings",
        "id": ",".join(channel_ids[:50]),
    })
    out = []
    for it in data.get("items", []):
        stats = it.get("statistics", {})
        snip = it.get("snippet", {})
        subs = int(stats.get("subscriberCount", 0) or 0)
        views = int(stats.get("viewCount", 0) or 0)
        vids = int(stats.get("videoCount", 0) or 0)
        desc = snip.get("title", "") + "\n" + snip.get("description", "")
        branding = it.get("brandingSettings", {}).get("channel", {})
        desc += "\n" + branding.get("description", "")
        email = EMAIL_RE.search(desc)
        out.append({
            "channel_id": it["id"],
            "title": snip.get("title", ""),
            "custom_url": snip.get("customUrl", ""),
            "subs": subs,
            "avg_views": (views // vids) if vids else 0,
            "email": email.group(0) if email else "",
        })
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("keywords", nargs="+", help="niche search terms")
    ap.add_argument("--min-subs", type=int, default=5000)
    ap.add_argument("--max-subs", type=int, default=500000)
    ap.add_argument("--out", default="leads.csv")
    args = ap.parse_args()

    if not os.environ.get("YOUTUBE_API_KEY"):
        sys.exit("Set YOUTUBE_API_KEY first (see the header of this file).")

    seen, rows = set(), []
    for kw in args.keywords:
        try:
            ids = search_channels(kw)
        except Exception as e:  # noqa: BLE001 — surface API/quota errors plainly
            sys.exit(f"YouTube API error on '{kw}': {e}")
        for ch in channel_details(ids):
            cid = ch["channel_id"]
            if cid in seen:
                continue
            if not (args.min_subs <= ch["subs"] <= args.max_subs):
                continue
            seen.add(cid)
            handle = ch["custom_url"] or ("@" + ch["title"].replace(" ", ""))
            rows.append({
                "email": ch["email"],
                "first_name": ch["title"].split()[0] if ch["title"] else "",
                "handle": handle,
                "platform": "youtube",
                "followers": ch["subs"],
                "avg_likes": ch["avg_views"],   # avg views/video (YT proxy)
                "niche": kw,
                "hook": "",                      # add a real one before sending
            })

    rows.sort(key=lambda r: (r["avg_likes"] / r["followers"]) if r["followers"] else 0,
              reverse=True)

    cols = ["email", "first_name", "handle", "platform", "followers",
            "avg_likes", "niche", "hook"]
    with open(args.out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(rows)

    with_email = sum(1 for r in rows if r["email"])
    print(f"✓ {len(rows)} channels → {args.out}")
    print(f"  {with_email} have an email in their description; "
          f"fill the rest from their link-in-bio.")
    print("  Next: add a personal `hook` per row, then run generate_emails.py.")


if __name__ == "__main__":
    main()
