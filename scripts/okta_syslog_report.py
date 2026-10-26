#!/usr/bin/env python3
"""
Okta System Log report for a PeopleSoft MFA rollout (read-only).

Kenneth P. Barnes · UCS Solutions

Summarizes the Okta events that matter during enrollment and enforcement waves:
enrollment progress, MFA failures, lockouts, policy rule hits, and possible MFA-fatigue
(push-bombing) patterns. It only reads data.

Two modes:
  * Live:    OKTA_ORG_URL and OKTA_API_TOKEN set; queries GET /api/v1/logs with pagination.
  * Offline: --input events.json  (a JSON array of System Log events, e.g. an export).

Examples:
  python3 okta_syslog_report.py --input ../tests/sample-syslog.json
  OKTA_ORG_URL=https://example.okta.com OKTA_API_TOKEN=... \
      python3 okta_syslog_report.py --hours 24 --app-label "PeopleSoft Financials"
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
import sys
from typing import Iterable, Iterator

EVENT_TYPES = [
    "user.session.start",
    "user.authentication.sso",
    "user.authentication.auth_via_mfa",
    "policy.evaluate_sign_on",
    "user.mfa.factor.activate",
    "user.mfa.factor.deactivate",
    "user.account.lock",
]
FATIGUE_THRESHOLD = 5          # failed MFA challenges for one user ...
FATIGUE_WINDOW_MIN = 10        # ... within this many minutes


def fetch_live(org_url: str, token: str, since: dt.datetime, until: dt.datetime) -> Iterator[dict]:
    """Yield System Log events from the Okta API (read-only GET with Link-header pagination)."""
    import requests  # imported here so offline mode has no dependency

    flt = " or ".join(f'eventType eq "{e}"' for e in EVENT_TYPES)
    url = f"{org_url.rstrip('/')}/api/v1/logs"
    params = {
        "since": since.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        "until": until.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        "filter": flt,
        "limit": 1000,
        "sortOrder": "ASCENDING",
    }
    headers = {"Authorization": f"SSWS {token}", "Accept": "application/json"}
    session = requests.Session()
    while url:
        resp = session.get(url, headers=headers, params=params, timeout=60)
        resp.raise_for_status()
        batch = resp.json()
        if not batch:
            break
        yield from batch
        url = resp.links.get("next", {}).get("url")
        params = None  # the next link already carries the query


def load_offline(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, list):
        raise ValueError("Input must be a JSON array of System Log events")
    return data


def parse_ts(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def targets_app(event: dict, app_label: str | None) -> bool:
    if not app_label:
        return True
    return any((t.get("displayName") or "") == app_label for t in event.get("target") or [])


def summarize(events: Iterable[dict], app_label: str | None = None) -> dict:
    counts: collections.Counter = collections.Counter()
    outcomes: collections.Counter = collections.Counter()
    mfa_fail_by_user: dict[str, list[dt.datetime]] = collections.defaultdict(list)
    rule_hits: collections.Counter = collections.Counter()
    enrolled_users: set[str] = set()
    locked_users: set[str] = set()

    for ev in events:
        etype = ev.get("eventType", "")
        if etype not in EVENT_TYPES:
            continue
        if etype in ("user.authentication.sso", "policy.evaluate_sign_on") and not targets_app(ev, app_label):
            continue
        user = (ev.get("actor") or {}).get("alternateId", "unknown")
        result = (ev.get("outcome") or {}).get("result", "UNKNOWN")
        counts[etype] += 1
        outcomes[(etype, result)] += 1

        if etype == "user.authentication.auth_via_mfa" and result in ("FAILURE", "DENY"):
            mfa_fail_by_user[user].append(parse_ts(ev["published"]))
        elif etype == "user.mfa.factor.activate" and result == "SUCCESS":
            enrolled_users.add(user)
        elif etype == "user.account.lock":
            locked_users.add(user)
        elif etype == "policy.evaluate_sign_on":
            rule = None
            for t in ev.get("target") or []:
                if t.get("type") == "Rule":
                    rule = t.get("displayName")
            rule_hits[rule or "(rule not reported)"] += 1

    fatigue = []
    window = dt.timedelta(minutes=FATIGUE_WINDOW_MIN)
    for user, times in mfa_fail_by_user.items():
        times.sort()
        start = 0
        for end in range(len(times)):
            while times[end] - times[start] > window:
                start += 1
            if end - start + 1 >= FATIGUE_THRESHOLD:
                fatigue.append({"user": user, "failures_in_window": end - start + 1,
                                "window_end": times[end].isoformat()})
                break

    mfa_total = sum(v for (e, _), v in outcomes.items() if e == "user.authentication.auth_via_mfa")
    mfa_fail = sum(v for (e, r), v in outcomes.items() if e == "user.authentication.auth_via_mfa" and r in ("FAILURE", "DENY"))
    return {
        "event_counts": dict(counts),
        "mfa_challenges": mfa_total,
        "mfa_failures": mfa_fail,
        "mfa_failure_rate_pct": round(100.0 * mfa_fail / mfa_total, 2) if mfa_total else 0.0,
        "users_enrolled_in_period": len(enrolled_users),
        "users_locked_in_period": sorted(locked_users),
        "policy_rule_hits": dict(rule_hits),
        "possible_mfa_fatigue": fatigue,
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--input", help="Offline JSON array of System Log events")
    ap.add_argument("--hours", type=int, default=24, help="Live mode look-back window (default 24)")
    ap.add_argument("--app-label", default=None, help="Only count SSO / policy events for this app label")
    args = ap.parse_args(argv)

    if args.input:
        events: Iterable[dict] = load_offline(args.input)
    else:
        org, token = os.environ.get("OKTA_ORG_URL"), os.environ.get("OKTA_API_TOKEN")
        if not org or not token:
            print("Set OKTA_ORG_URL and OKTA_API_TOKEN, or use --input for offline mode.", file=sys.stderr)
            return 2
        until = dt.datetime.now(dt.timezone.utc)
        events = fetch_live(org, token, until - dt.timedelta(hours=args.hours), until)

    print(json.dumps(summarize(events, args.app_label), indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
