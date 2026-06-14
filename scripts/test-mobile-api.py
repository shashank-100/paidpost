#!/usr/bin/env python3
"""
End-to-end smoke test for the PaidPost mobile API.

Authenticates via the Apple-review bypass, then hits every endpoint the iOS
app calls and reports pass/fail. Read-only (GET) endpoints are called directly;
mutating endpoints are called with harmless/no-op payloads where safe, or just
checked for reachability (non-5xx) otherwise.

Usage:
    python3 scripts/test-mobile-api.py
    BASE=https://paidpost.vercel.app python3 scripts/test-mobile-api.py
"""

import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("BASE", "https://paidpost.vercel.app") + "/api/mobile"
TEST_EMAIL = "test-user-0-apple@gmail.com"
TEST_CODE = "000000"

GREEN, RED, YELLOW, RESET = "\033[32m", "\033[31m", "\033[33m", "\033[0m"


def request(method, path, token=None, body=None, timeout=25):
    url = f"{BASE}/{path}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()
    except Exception as e:  # noqa: BLE001
        return 0, str(e)


def authenticate():
    status, raw = request(
        "POST", "auth/test-bypass", body={"email": TEST_EMAIL, "code": TEST_CODE}
    )
    if status != 200:
        print(f"{RED}AUTH FAILED ({status}){RESET}: {raw[:200]}")
        sys.exit(1)
    token = json.loads(raw).get("access_token")
    if not token:
        print(f"{RED}AUTH returned no token{RESET}: {raw[:200]}")
        sys.exit(1)
    print(f"{GREEN}✓ auth/test-bypass{RESET} — got session token\n")
    return token


# (method, path, expect_ok_statuses, label)
# Read-only endpoints the iOS app calls. 2xx = pass; 4xx that's an expected
# "no data / not applicable" is treated as reachable-OK where noted.
READ_ENDPOINTS = [
    ("GET", "version-check", {200}, "version check (unauth)"),
    ("GET", "jobs", {200}, "jobs feed"),
    ("GET", "applications", {200}, "my applications"),
    ("GET", "creator/profile", {200, 404}, "creator profile"),
    ("GET", "creator/managed-status", {200, 404}, "managed status"),
    ("GET", "creator/suggest-handles", {200, 400}, "suggested handles"),
    ("GET", "creators/wallet", {200, 404}, "wallet"),
    ("GET", "notifications", {200}, "notifications"),
    ("GET", "notifications/unread-count", {200}, "unread count"),
    ("GET", "inbox", {200}, "inbox threads"),
]

# Mutating endpoints — only ones that are safe / idempotent to probe.
WRITE_ENDPOINTS = [
    ("POST", "notifications/mark-read", {"notification_ids": []}, {200}, "mark notifications read"),
    # Payouts aren't wired yet (no STRIPE_SECRET_KEY) — 500 is expected until
    # Stripe is configured. The app gates this behind "payouts coming soon".
    ("POST", "creators/stripe-connect",
     {"return_url": "https://paidpost.vercel.app/stripe-return",
      "refresh_url": "https://paidpost.vercel.app/stripe-refresh"},
     {200, 400, 409, 500}, "stripe connect link (payouts not yet wired)"),
]


def discover_brand_slug(token):
    """Find a brandSlug the test creator is working with, if any. posts/videos
    are scoped to a brand the creator has an active workspace for."""
    status, raw = request("GET", "creator/managed-status", token=token)
    if status == 200:
        try:
            data = json.loads(raw)
            # managed-status / workspace shapes vary; scan for a slug field.
            for key in ("brand_slug", "brandSlug", "organization_slug"):
                if isinstance(data, dict) and data.get(key):
                    return data[key]
        except Exception:  # noqa: BLE001
            pass
    return None


def main():
    token = authenticate()
    passed = failed = skipped = 0

    print("== Read endpoints ==")
    for method, path, ok, label in READ_ENDPOINTS:
        status, _ = request(method, path, token=token if path != "version-check" else None)
        good = status in ok
        mark = f"{GREEN}PASS{RESET}" if good else f"{RED}FAIL{RESET}"
        print(f"  {mark}  {status:>3}  {method} /{path}  ({label})")
        passed += good
        failed += not good

    print("\n== Brand-scoped endpoints ==")
    slug = discover_brand_slug(token)
    for path, label in [("creator/posts", "creator posts"), ("creator/videos", "creator videos")]:
        if slug:
            status, _ = request("GET", f"{path}?brandSlug={slug}", token=token)
            good = status == 200
            mark = f"{GREEN}PASS{RESET}" if good else f"{RED}FAIL{RESET}"
            print(f"  {mark}  {status:>3}  GET /{path}?brandSlug={slug}  ({label})")
            passed += good
            failed += not good
        else:
            print(f"  {YELLOW}SKIP{RESET}    -  GET /{path}  ({label} — test account has no active campaign)")
            skipped += 1

    print("\n== Write endpoints (safe probes) ==")
    for method, path, body, ok, label in WRITE_ENDPOINTS:
        status, _ = request(method, path, token=token, body=body)
        good = status in ok
        mark = f"{GREEN}PASS{RESET}" if good else f"{YELLOW}WARN{RESET}"
        print(f"  {mark}  {status:>3}  {method} /{path}  ({label})")
        passed += good
        # write probes count as warnings, not hard failures
    print(f"\n{passed} passed, {failed} failed, {skipped} skipped")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
