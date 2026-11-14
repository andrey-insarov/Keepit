#!/usr/bin/env python3
"""Tell IndexNow (indexnow.org: Bing, Yandex, Naver, Seznam, Yep) which keep.it.com pages changed.

  python3 Scripts/indexnow.py --since <commit>   pages whose HTML differs between <commit> and HEAD
  python3 Scripts/indexnow.py --all              every URL in docs/site/sitemap.xml
  add --dry-run to print the URLs and send nothing

A page is submitted only when the sitemap lists it, so 404.html and the frozen /v2/ pages never
go out. A deleted page is submitted too (the engines then see the 404 and drop it) when the
sitemap at <commit> still listed it. The key is the docs/site/<key>.txt file whose content equals
its name; it is public by design. Standard library only. Run it after the deployment is live:
the engines fetch the pages and the key file as soon as the request arrives.
"""
from __future__ import annotations

import argparse
import html
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit

ENDPOINT = "https://api.indexnow.org/indexnow"
SITE_DIR = "docs/site"
KEY_RE = re.compile(r"[A-Za-z0-9-]{8,128}")     # the protocol's key alphabet and length
MAX_URLS = 10_000                               # per request, by the protocol

root = Path(__file__).resolve().parent.parent
site = root / SITE_DIR


def sitemap_urls(xml: str) -> list[str]:
    """Every <loc> of a sitemap, in file order."""
    return [html.unescape(m.strip()) for m in re.findall(r"<loc>([^<]+)</loc>", xml)]


def page_url(rel: str, base: str) -> str | None:
    """Public URL of docs/site/<rel>, or None when the file is not a page.
    Cloudflare Pages serves x.html at /x and x/index.html at /x/."""
    if not rel.endswith(".html"):
        return None
    path = rel[: -len(".html")]
    if path == "index":
        path = ""
    elif path.endswith("/index"):
        path = path[: -len("index")]
    return base + path


def changed_urls(status_lines: list[str], base: str, now: set[str], before: set[str]) -> list[str]:
    """URLs to submit for `git diff --name-status --no-renames` lines with paths relative to
    docs/site. Added or modified pages count when the current sitemap lists them, deleted pages
    when the old one did."""
    out: list[str] = []
    for line in status_lines:
        status, _, rel = line.partition("\t")
        url = page_url(rel.strip(), base)
        if url is None:
            continue
        listed = before if status.startswith("D") else now
        if url in listed and url not in out:
            out.append(url)
    return out


def find_key() -> str:
    keys = [p.stem for p in sorted(site.glob("*.txt"))
            if KEY_RE.fullmatch(p.stem) and p.read_text(encoding="utf-8").strip() == p.stem]
    if len(keys) != 1:
        raise SystemExit(f"expected exactly one IndexNow key file in {SITE_DIR}, found {len(keys)}")
    return keys[0]


def git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True, text=True).stdout


def submit(urls: list[str], base: str, key: str, endpoint: str = ENDPOINT) -> int:
    """POST the URLs; returns the HTTP status. 200 = accepted, 202 = accepted, key check pending."""
    body = json.dumps({"host": urlsplit(base).netloc, "key": key,
                       "keyLocation": f"{base}{key}.txt", "urlList": urls}).encode("utf-8")
    req = urllib.request.Request(endpoint, data=body, method="POST", headers={
        "Content-Type": "application/json; charset=utf-8",
        "User-Agent": "keepit-site-indexnow (+https://keep.it.com)"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        print(e.read().decode("utf-8", "replace")[:500], file=sys.stderr)
        return e.code


def main() -> int:
    ap = argparse.ArgumentParser(description="Submit changed keep.it.com pages to IndexNow.")
    what = ap.add_mutually_exclusive_group(required=True)
    what.add_argument("--since", metavar="COMMIT", help="pages changed between COMMIT and HEAD")
    what.add_argument("--all", action="store_true", help="every URL in the sitemap")
    ap.add_argument("--dry-run", action="store_true", help="print the URLs, send nothing")
    ap.add_argument("--endpoint", default=ENDPOINT, help=argparse.SUPPRESS)
    args = ap.parse_args()

    listed = sitemap_urls((site / "sitemap.xml").read_text(encoding="utf-8"))
    if not listed:
        raise SystemExit("sitemap.xml lists no URLs")
    base = listed[0]                                 # the landing page comes first: https://keep.it.com/
    if urlsplit(base).path != "/" or any(not u.startswith(base) for u in listed):
        raise SystemExit(f"sitemap.xml must start with the site root and stay on one host, got {base}")

    if args.all:
        urls = listed
    else:
        try:
            git("rev-parse", "--verify", "--quiet", f"{args.since}^{{commit}}")
        except subprocess.CalledProcessError:
            raise SystemExit(f"{args.since} is not a commit in this checkout (a shallow clone?)")
        try:
            old = sitemap_urls(git("show", f"{args.since}:{SITE_DIR}/sitemap.xml"))
        except subprocess.CalledProcessError:
            old = []                                 # no sitemap at that commit
        diff = git("diff", "--name-status", "--no-renames", f"--relative={SITE_DIR}/",
                   args.since, "HEAD", "--", SITE_DIR)
        urls = changed_urls(diff.splitlines(), base, set(listed), set(old))

    if not urls:
        print("IndexNow: no pages changed, nothing to submit")
        return 0
    if len(urls) > MAX_URLS:
        raise SystemExit(f"{len(urls)} URLs exceed the {MAX_URLS} per request the protocol allows")
    print("\n".join(urls))
    if args.dry_run:
        print(f"IndexNow: dry run, {len(urls)} URL(s) not sent")
        return 0

    status = submit(urls, base, find_key(), args.endpoint)
    if status not in (200, 202):
        print(f"IndexNow: HTTP {status}, {len(urls)} URL(s) not accepted", file=sys.stderr)
        return 1
    print(f"IndexNow: HTTP {status}, {len(urls)} URL(s) submitted")
    return 0


if __name__ == "__main__":
    sys.exit(main())
