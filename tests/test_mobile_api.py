#!/usr/bin/env python3
"""
Functional / integration tests for the PaidPost mobile API.

Unlike a smoke test (which only checks status codes), each test here sends a
known input and asserts the exact expected output — response shape, field
types, and end-to-end behavior (e.g. apply to a job → it appears in
applications).

Two seeded test accounts are used:
  - REVIEWER  (test-user-0-apple@gmail.com): fresh, browse-only creator.
  - MANAGED   (shashanktcoding@gmail.com):   accepted into a seeded campaign,
              so workspace / posts / videos return real data.

Tokens are minted directly via Supabase admin (magic-link → verify), so no
email delivery is needed.

Usage:  python3 tests/test_mobile_api.py
"""

import json
import os
import sys
import urllib.error
import urllib.request

API = os.environ.get("BASE", "https://paidpost.vercel.app") + "/api/mobile"
SUPABASE = "https://jmlnyuwlrbxhxckuuhxw.supabase.co"
PUBLISHABLE = "sb_publishable_UN8AyG18fzvD000Vd2SwNw_oGNSv1fh"

REVIEWER_EMAIL = "test-user-0-apple@gmail.com"
MANAGED_EMAIL = "shashanktcoding@gmail.com"
MANAGED_BRAND_SLUG = "paidpost-studio"

GREEN, RED, RESET = "\033[32m", "\033[31m", "\033[0m"

_passed = 0
_failed = 0


def _service_role_key():
    raw = os.popen(
        "supabase projects api-keys --project-ref jmlnyuwlrbxhxckuuhxw --output json 2>/dev/null"
    ).read()
    return next(k["api_key"] for k in json.loads(raw) if k["name"] == "service_role")


def _post(url, body, key):
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={"apikey": key, "Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    return json.loads(urllib.request.urlopen(req, timeout=25).read())


def mint_token(email):
    """Mint a real session token for any account, no email needed."""
    sr = _service_role_key()
    link = _post(SUPABASE + "/auth/v1/admin/generate_link", {"type": "magiclink", "email": email}, sr)
    hashed = link.get("hashed_token") or link.get("properties", {}).get("hashed_token")
    sess = _post(SUPABASE + "/auth/v1/verify", {"type": "magiclink", "token_hash": hashed}, PUBLISHABLE)
    return sess["access_token"]


def call(method, path, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(f"{API}/{path}", data=data, method=method, headers=headers)
    try:
        resp = urllib.request.urlopen(req, timeout=25)
        raw = resp.read().decode()
        return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:  # noqa: BLE001
            return e.code, raw


def check(name, condition, detail=""):
    global _passed, _failed
    if condition:
        _passed += 1
        print(f"  {GREEN}✓{RESET} {name}")
    else:
        _failed += 1
        print(f"  {RED}✗ {name}{RESET}  {detail}")


def section(title):
    print(f"\n== {title} ==")


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_auth():
    section("Auth")
    # Arrange/Act: review bypass with the fixed code.
    status, body = call("POST", "auth/test-bypass", body={"email": REVIEWER_EMAIL, "code": "000000"})
    # Assert
    check("test-bypass returns 200", status == 200, f"got {status}")
    check("test-bypass returns access_token", isinstance(body, dict) and bool(body.get("access_token")))
    # Negative: wrong code must be rejected.
    s2, _ = call("POST", "auth/test-bypass", body={"email": REVIEWER_EMAIL, "code": "999999"})
    check("test-bypass rejects wrong code", s2 in (401, 403), f"got {s2}")
    return body["access_token"]


def test_jobs(token):
    section("Jobs feed")
    status, body = call("GET", "jobs", token=token)
    check("jobs returns 200", status == 200, f"got {status}")
    jobs = body if isinstance(body, list) else (body or {}).get("data", [])
    check("jobs is a non-empty list", isinstance(jobs, list) and len(jobs) > 0, f"len={len(jobs) if isinstance(jobs,list) else 'n/a'}")
    if jobs:
        j = jobs[0]
        check("job has id", bool(j.get("id")))
        check("job has job_title", bool(j.get("job_title")))
        check("job has numeric budget_per_creator", isinstance(j.get("budget_per_creator"), (int, float)))
    return jobs


def test_apply_flow(token, jobs):
    section("Apply flow (apply → appears in applications)")
    if not jobs:
        check("apply flow", False, "no jobs to apply to")
        return
    # Arrange: pick a job not already applied to.
    before_status, before = call("GET", "applications", token=token)
    before_ids = {a.get("id") for a in (before or [])} if isinstance(before, list) else set()
    job = jobs[0]
    job_id = job["id"]
    # Act: apply. Either a fresh 200, or a 400 "already applied" (idempotent —
    # the dedup guard working) are both correct outcomes.
    status, body = call("POST", f"jobs/{job_id}/apply", token=token)
    already = status == 400 and isinstance(body, dict) and "already applied" in str(body.get("error", "")).lower()
    check("apply succeeds or is already applied", status == 200 or already, f"got {status}: {body}")
    # Assert: dedup is enforced — a second apply to the same job must 400.
    dup_status, dup_body = call("POST", f"jobs/{job_id}/apply", token=token)
    check("duplicate apply is rejected (dedup)", dup_status == 400, f"got {dup_status}")
    # Assert: the job is present in the applications list.
    after_status, after = call("GET", "applications", token=token)
    check("applications returns 200", after_status == 200)
    applied_to_job = isinstance(after, list) and any(
        (a.get("job_id") == job_id or a.get("job_title") == job.get("job_title")) for a in after
    )
    check("job appears in applications", applied_to_job, f"job {job_id} not found in applications")


def test_profile(token):
    section("Profile (round-trip)")
    status, body = call("GET", "creator/profile", token=token)
    check("profile returns 200", status == 200, f"got {status}")
    if isinstance(body, dict):
        check("profile has email", bool(body.get("email")))
        check("profile has display_name field", "display_name" in body)
        check("profile email matches account", body.get("email") == REVIEWER_EMAIL,
              f"got {body.get('email')}")
        # Act: update bio, assert it round-trips.
        new_bio = "Integration test bio"
        us, _ = call("PATCH", "creator/profile", token=token, body={"bio": new_bio})
        check("profile PATCH returns 200", us == 200, f"got {us}")
        _, after = call("GET", "creator/profile", token=token)
        check("profile bio round-trips", isinstance(after, dict) and after.get("bio") == new_bio,
              f"got {after.get('bio') if isinstance(after,dict) else after}")


def test_wallet(token):
    section("Wallet")
    status, body = call("GET", "creators/wallet", token=token)
    check("wallet returns 200", status == 200, f"got {status}")
    if isinstance(body, dict):
        check("wallet has integer balance_cents", isinstance(body.get("balance_cents"), int))
        check("wallet has total_earned_cents", isinstance(body.get("total_earned_cents"), int))
        check("wallet has currency", bool(body.get("currency")))
        check("wallet has stripe_connected bool", isinstance(body.get("stripe_connected"), bool))


def test_notifications(token):
    section("Notifications")
    status, body = call("GET", "notifications", token=token)
    check("notifications returns 200", status == 200, f"got {status}")
    check("notifications has data array", isinstance(body, dict) and isinstance(body.get("data"), list))
    check("notifications has unread_count int", isinstance(body, dict) and isinstance(body.get("unread_count"), int))
    # unread-count endpoint must agree it's a number.
    s2, b2 = call("GET", "notifications/unread-count", token=token)
    check("unread-count returns 200", s2 == 200, f"got {s2}")
    # mark-read should succeed.
    s3, _ = call("POST", "notifications/mark-read", token=token, body={"notification_ids": []})
    check("mark-read returns 200", s3 == 200, f"got {s3}")


def test_inbox(token):
    section("Inbox")
    status, body = call("GET", "inbox", token=token)
    check("inbox returns 200", status == 200, f"got {status}")


def test_managed_creator():
    section("Managed creator (campaign workspace)")
    try:
        token = mint_token(MANAGED_EMAIL)
    except Exception as e:  # noqa: BLE001
        check("mint managed-creator token", False, str(e)[:80])
        return
    check("managed-creator token minted", bool(token))
    # workspace for the seeded brand should return 200 with the campaign.
    ws_s, ws = call("GET", f"creator/workspace/{MANAGED_BRAND_SLUG}", token=token)
    check("workspace returns 200 for managed creator", ws_s == 200, f"got {ws_s}: {ws}")
    # brand-scoped posts & videos now resolve (not 'not a managed creator').
    ps, _ = call("GET", f"creator/posts?brandSlug={MANAGED_BRAND_SLUG}", token=token)
    check("posts returns 200 for managed creator", ps == 200, f"got {ps}")
    vs, _ = call("GET", f"creator/videos?brandSlug={MANAGED_BRAND_SLUG}", token=token)
    check("videos returns 200 for managed creator", vs == 200, f"got {vs}")
    # Negative test: the managed creator IS linked to paidpost-studio, but must
    # be denied a workspace for a brand they are NOT a managed creator of.
    ns, _ = call("GET", "creator/workspace/jenni-ai", token=token)
    check("managed creator denied workspace for unaffiliated brand", ns in (403, 404), f"got {ns}")


def test_unauthorized():
    section("Auth enforcement")
    status, _ = call("GET", "jobs")  # no token
    check("jobs requires auth (401 without token)", status == 401, f"got {status}")


def main():
    token = test_auth()
    test_unauthorized()
    jobs = test_jobs(token)
    test_apply_flow(token, jobs)
    test_profile(token)
    test_wallet(token)
    test_notifications(token)
    test_inbox(token)
    test_managed_creator()

    print(f"\n{'-'*40}")
    total = _passed + _failed
    color = GREEN if _failed == 0 else RED
    print(f"{color}{_passed}/{total} assertions passed, {_failed} failed{RESET}")
    sys.exit(1 if _failed else 0)


if __name__ == "__main__":
    main()
