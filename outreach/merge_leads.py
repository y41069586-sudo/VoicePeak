#!/usr/bin/env python3
"""
Glowé lead merger — combine ANY creator CSVs into one clean leads.csv.

Feed it exports from anywhere (find_youtube.py output, an Apify actor export
you ran yourself, a hand-collected sheet) — it auto-detects columns, digs
emails out of bio/description text, dedupes across all sources, validates,
ranks by engagement, and writes the standard leads.csv that
generate_emails.py consumes.

Usage:
    python3 merge_leads.py apify_export.csv youtube_leads.csv manual.csv
    python3 merge_leads.py *.csv --out leads.csv

Column auto-detection (case-insensitive, first match wins):
    email     : email, businessEmail, business_email, public_email, contact
    handle    : handle, username, uniqueId, channel, custom_url, account
    name      : first_name, name, fullName, full_name, title, nickname
    followers : followers, followersCount, follower_count, fans, subs,
