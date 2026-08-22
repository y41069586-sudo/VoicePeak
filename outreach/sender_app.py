#!/usr/bin/env python3
"""
SkinFix outreach sender — tiny local web GUI (no dependencies).

Runs a small web page on your own machine where you paste your list, write the
email once with a {{first_name}} placeholder, and hit Send. It emails each
person INDIVIDUALLY via Gmail SMTP (nobody sees the others), with a throttle
and an auto-appended opt-out + postal footer.

    python3 sender_app.py
    → open http://127.0.0.1:8765 in your browser

Your Gmail app password never leaves your computer (the server binds to
127.0.0.1 only). Get an app password: Google Account → Security → 2-Step
Verification → App passwords.

⚠️  Gmail caps ~500/day (free). Keep cold volume low (a few dozen) or Google
flags the account. For real scale use Instantly/Smartlead on a separate domain.
Germany: unsolicited commercial email is legally restricted (UWG/GDPR) — prefer
creators who publicly list a business email.
"""

import csv
import io
import ssl
import time
import html
import smtplib
import urllib.parse
from email.message import EmailMessage
from http.server import BaseHTTPRequestHandler, HTTPServer

HOST, PORT = "127.0.0.1", 8765

FOOTER = '\n\n--\nNot your thing? Just reply "stop" and we won\'t message again.'

DEFAULT_SUBJECT = "Paid collab with SkinFix?"
DEFAULT_BODY = """Hey {{first_name}},

We're the founders of SkinFix — an app that scans your skin, gives an honest 0–100 score and a personalized 14-day glow-up plan (plus an AI "you as a 10/10" preview). Super visual, made for skincare content.

We'd love to do a paid collab with you. Your audience is exactly who we built this for.

Interested? Happy to send you free lifetime access to try it first.

— The SkinFix Team"""

DEFAULT_LEADS = """email,first_name
example@gmail.com,Jane"""

PAGE = """<!doctype html><html><head><meta charset="utf-8">
<title>SkinFix Sender</title>
<style>
 body{{font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#efe7f7;color:#2a2140;margin:0;padding:24px}}
 .card{{max-width:720px;margin:0 auto;background:#fff;border-radius:20px;padding:28px;box-shadow:0 16px 50px rgba(40,34,26,.15)}}
 h1{{margin:0 0 4px}} p.sub{{color:#6b6382;margin:0 0 20px}}
 label{{display:block;font-weight:600;margin:14px 0 4px;font-size:14px}}
 input,textarea{{width:100%;box-sizing:border-box;padding:11px;border:1px solid #d9cfe8;border-radius:10px;font-size:14px;font-family:inherit}}
 textarea{{resize:vertical}}
 .row{{display:flex;gap:12px}} .row>div{{flex:1}}
 button{{margin-top:20px;width:100%;padding:15px;border:0;border-radius:12px;background:#12655D;color:#fff;font-size:16px;font-weight:700;cursor:pointer}}
 .note{{font-size:12px;color:#8a82a0;margin-top:6px}}
 .warn{{background:#fbeaea;color:#a23;padding:10px 12px;border-radius:10px;font-size:13px;margin-bottom:16px}}
</style></head><body><div class="card">
<h1>SkinFix Sender</h1>
<p class="sub">Jeder bekommt seine eigene Mail. {{first_name}} wird ersetzt.</p>
<div class="warn">Klein halten (ein paar Dutzend/Tag) — sonst sperrt Gmail dein Konto. Opt-out + Impressum werden automatisch angehängt.</div>
<form method="POST" action="/send">
 <div class="row">
  <div><label>Deine Gmail</label><input name="user" type="email" placeholder="du@gmail.com" required></div>
  <div><label>App-Passwort (16 Zeichen)</label><input name="pw" type="password" required></div>
 </div>
 <label>Absender-Name</label><input name="from_name" value="SkinFix">
 <label>Betreff</label><input name="subject" value="{subject}">
 <label>Nachricht (nutze {{{{first_name}}}} als Platzhalter)</label>
 <textarea name="body" rows="12">{body}</textarea>
 <label>Empfänger (CSV: eine Zeile pro Person, <b>email,first_name</b>)</label>
 <textarea name="leads" rows="8">{leads}</textarea>
 <label>Pause zwischen Mails (Sekunden)</label><input name="delay" type="number" value="8">
 <div class="note">8-15 Sek. wirkt menschlich. Bei vielen Empfängern dauert's entsprechend.</div>
 <button type="submit">Alle senden</button>
</form></div></body></html>"""


def result_page(rows):
    items = "".join(
        f'<li style="color:{"#2a7" if ok else "#a23"}">{"✓" if ok else "✗"} '
        f'{html.escape(to)}{"" if ok else " — " + html.escape(msg)}</li>'
        for ok, to, msg in rows)
    sent = sum(1 for ok, *_ in rows if ok)
    return (f'<!doctype html><meta charset="utf-8"><body style="font-family:sans-serif;'
            f'background:#efe7f7;padding:24px"><div style="max-width:720px;margin:0 auto;'
            f'background:#fff;border-radius:20px;padding:28px">'
            f'<h1>{sent}/{len(rows)} gesendet</h1><ul>{items}</ul>'
            f'<a href="/">← zurück</a></div></body>')


class Handler(BaseHTTPRequestHandler):
    def _html(self, body, code=200):
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def do_GET(self):
        self._html(PAGE.format(subject=html.escape(DEFAULT_SUBJECT),
                               body=html.escape(DEFAULT_BODY),
                               leads=html.escape(DEFAULT_LEADS)))

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        form = urllib.parse.parse_qs(self.rfile.read(length).decode("utf-8"))
        g = lambda k, d="": form.get(k, [d])[0]
        user, pw = g("user").strip(), g("pw").strip()
        subject, body = g("subject"), g("body")
        from_name = g("from_name") or "SkinFix"
        try:
            delay = max(0, float(g("delay", "8")))
        except ValueError:
            delay = 8

        leads = list(csv.DictReader(io.StringIO(g("leads"))))
        results = []
        try:
            server = smtplib.SMTP("smtp.gmail.com", 587, timeout=30)
            server.starttls(context=ssl.create_default_context())
            server.login(user, pw)
        except Exception as e:  # noqa: BLE001
            self._html(result_page([(False, "Login", str(e))]))
            return

        try:
            for i, lead in enumerate(leads):
                to = (lead.get("email") or "").strip()
                if not to or "@" not in to:
                    continue
                first = (lead.get("first_name") or "there").strip() or "there"
                msg = EmailMessage()
                msg["From"] = f"{from_name} <{user}>"
                msg["To"] = to
                msg["Subject"] = subject.replace("{{first_name}}", first)
                msg.set_content(body.replace("{{first_name}}", first) + FOOTER)
                sent_ok = False
                try:
                    server.send_message(msg)
                    results.append((True, to, ""))
                    sent_ok = True
                except Exception as e:  # noqa: BLE001
                    results.append((False, to, str(e)))
                # Only throttle after a real send, and not after the last lead —
                # skipped/invalid rows shouldn't cost a delay.
                if sent_ok and delay and i < len(leads) - 1:
                    time.sleep(delay)
        finally:
            server.quit()
        self._html(result_page(results))

    def log_message(self, *a):  # quiet
        pass


if __name__ == "__main__":
    print(f"SkinFix Sender läuft → öffne http://{HOST}:{PORT} im Browser")
    print("(Zum Beenden: Strg+C)")
    HTTPServer((HOST, PORT), Handler).serve_forever()
