#!/usr/bin/env python3
"""
Gmail SMTP sender — throttled, opt-out-aware, small-batch by design.

Sends the first email of the sequence (subject_1 / body_1 from
generate_emails.py's outreach_ready.csv) via your Gmail over SMTP. Built for
HAND-PICKED, small-volume outreach — NOT a bulk blaster.

⚠️  READ BEFORE USING
- Gmail caps sending at ~500/day (free) / ~2000/day (Workspace). Cold bulk far
  below that still gets accounts flagged/suspended. Keep it small (a few dozen
  a day, to well-targeted creators). For real scale use Instantly/Smartlead on
  a SEPARATE domain — not your primary Gmail.
- Germany (UWG §7 / GDPR): unsolicited commercial email is legally restricted.
  Prefer creators who publicly invite "business inquiries". Every template
  already carries an opt-out line + your postal identity — keep them.

Setup:
    1. Enable 2-Step Verification on the Google account.
    2. Create an App Password (Google Account → Security → App passwords).
    3. export GMAIL_USER="you@gmail.com"
       export GMAIL_APP_PASSWORD="the-16-char-app-password"

Usage:
    python3 send_gmail.py outreach_ready.csv --dry-run        # preview, sends nothing
    python3 send_gmail.py outreach_ready.csv --limit 20       # send to first 20
    # already-sent addresses (logged in sent_log.csv) are skipped automatically.
"""

import csv
import os
import ssl
import sys
import time
import argparse
import smtplib
from email.message import EmailMessage

SENT_LOG = "sent_log.csv"


def load_suppression(extra_file):
    """Emails to never contact: prior sends + an optional manual list."""
    done = set()
    for path in (SENT_LOG, extra_file):
        if path and os.path.exists(path):
            with open(path, newline="", encoding="utf-8") as f:
                for row in csv.reader(f):
                    if row:
                        done.add(row[0].strip().lower())
    return done


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv", help="outreach_ready.csv from generate_emails.py")
    ap.add_argument("--limit", type=int, default=25,
                    help="max emails this run (default 25 — keep it small)")
    ap.add_argument("--delay", type=float, default=90,
                    help="seconds between sends (default 90 — looks human, avoids flags)")
    ap.add_argument("--suppress", help="optional CSV of emails to skip (opt-outs)")
    ap.add_argument("--from-name", default="SkinFix")
    ap.add_argument("--dry-run", action="store_true", help="print, send nothing")
    args = ap.parse_args()

    user = os.environ.get("GMAIL_USER")
    pw = os.environ.get("GMAIL_APP_PASSWORD")
    if not args.dry_run and not (user and pw):
        sys.exit("Set GMAIL_USER and GMAIL_APP_PASSWORD first (see header).")

    if args.limit > 50:
        print(f"⚠️  limit={args.limit}: sending >50/day from Gmail risks a flag. "
              f"Consider a proper tool + separate domain for scale.")

    done = load_suppression(args.suppress)
    with open(args.csv, newline="", encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f)
                if r.get("email", "").strip()
                and r["email"].strip().lower() not in done]

    rows = rows[:args.limit]
    if not rows:
        print("Nothing to send (all suppressed or empty).")
        return

    server = None
    if not args.dry_run:
        server = smtplib.SMTP("smtp.gmail.com", 587, timeout=30)
        server.starttls(context=ssl.create_default_context())
        server.login(user, pw)

    sent = 0
    log = open(SENT_LOG, "a", newline="", encoding="utf-8")
    logger = csv.writer(log)
    try:
        for i, row in enumerate(rows):
            to = row["email"].strip()
            subject = row.get("subject_1") or "Paid collab with SkinFix?"
            body = row.get("body_1") or ""
            if args.dry_run:
                print(f"[dry-run] → {to} | {subject}")
                sent += 1
                continue

            msg = EmailMessage()
            msg["From"] = f"{args.from_name} <{user}>"
            msg["To"] = to
            msg["Subject"] = subject
            msg.set_content(body)
            try:
                server.send_message(msg)
                logger.writerow([to, subject]); log.flush()
                sent += 1
                print(f"✓ {sent}/{len(rows)} → {to}")
            except Exception as e:  # noqa: BLE001 — keep going on one bad address
                print(f"✗ failed → {to}: {e}")

            if i < len(rows) - 1:
                time.sleep(args.delay)   # throttle
    finally:
        log.close()
        if server:
            server.quit()

    print(f"\nDone. {sent} email(s) {'previewed' if args.dry_run else 'sent'}. "
          f"Logged to {SENT_LOG} (skipped next run).")


if __name__ == "__main__":
    main()
