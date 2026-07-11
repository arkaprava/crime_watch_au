#!/usr/bin/env python3
"""Sampled bulk suburb test — 1250 suburbs per state (10,000 total)."""

import json
import random
import sys
import time
import urllib.request
import urllib.error
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from pathlib import Path

GRAPHQL_URL = "http://127.0.0.1:8080/graphql"
API_KEY = "dev-read-key"
SUBURBS_PATH = Path(__file__).parent.parent / "assets/data/australian_suburbs.json"
PER_STATE = 1250  # 8 states * 1250 = 10,000
CONCURRENCY = 3
TIMEOUT_SEC = 30

QUERY = """
query CrimeIncidents($city: String, $state: String, $limit: Int) {
  crimeIncidents(city: $city, state: $state, limit: $limit) {
    id title offenceCount granularity geocodeStatus
    location { city state }
  }
}
"""


@dataclass
class Result:
    name: str
    state: str
    has_coords: bool
    ok: bool = False
    ms: float = 0
    count: int = 0
    error: str | None = None
    issues: list[str] = field(default_factory=list)


def graphql(city, state):
    payload = json.dumps({"query": QUERY, "variables": {"city": city, "state": state, "limit": 10}}).encode()
    req = urllib.request.Request(GRAPHQL_URL, data=payload, headers={"Content-Type": "application/json", "X-API-Key": API_KEY})
    start = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as resp:
            body = json.loads(resp.read())
            ms = (time.monotonic() - start) * 1000
            if "errors" in body:
                return None, ms, "; ".join(e.get("message", str(e)) for e in body["errors"])
            data = (body.get("data") or {}).get("crimeIncidents") or []
            return data, ms, None
    except Exception as e:
        return None, (time.monotonic() - start) * 1000, str(e)


def test(entry):
    name, state = entry["n"], entry["s"]
    r = Result(name, state, entry.get("lat") is not None)
    data, ms, err = graphql(name, state)
    r.ms = ms
    if err:
        r.error = err
        if "timed out" in err.lower():
            r.issues.append("timeout")
        else:
            r.issues.append("error")
    else:
        r.ok = True
        r.count = len(data)
        if ms > 3000:
            r.issues.append("slow")
        if r.count == 0:
            r.issues.append("no_data")
    return r


def main():
    random.seed(42)
    with open(SUBURBS_PATH) as f:
        all_suburbs = json.load(f)

    by_state = defaultdict(list)
    for s in all_suburbs:
        by_state[s["s"]].append(s)

    sample = []
    for state in sorted(by_state):
        pool = by_state[state]
        n = min(PER_STATE, len(pool))
        sample.extend(random.sample(pool, n))

    print(f"Testing {len(sample)} suburbs ({PER_STATE} per state, {len(by_state)} states)")
    results = []
    t0 = time.monotonic()

    with ThreadPoolExecutor(max_workers=CONCURRENCY) as ex:
        futs = {ex.submit(test, s): s for s in sample}
        done = 0
        for fut in as_completed(futs):
            results.append(fut.result())
            done += 1
            if done % 100 == 0:
                print(f"  {done}/{len(sample)} ({time.monotonic()-t0:.0f}s)", flush=True)

    elapsed = time.monotonic() - t0
    issue_cat = Counter()
    for r in results:
        for i in r.issues:
            issue_cat[i] += 1

    state_stats = defaultdict(lambda: {"tested": 0, "with_data": 0, "errors": 0, "timeouts": 0, "slow": 0})
    for r in results:
        ss = state_stats[r.state]
        ss["tested"] += 1
        if r.count > 0:
            ss["with_data"] += 1
        if r.error:
            ss["errors"] += 1
        if "timeout" in r.issues:
            ss["timeouts"] += 1
        if "slow" in r.issues:
            ss["slow"] += 1

    ok = sum(1 for r in results if r.ok)
    with_data = sum(1 for r in results if r.count > 0)
    errors = sum(1 for r in results if r.error)
    timeouts = issue_cat["timeout"]
    slow = issue_cat["slow"]
    no_data = issue_cat["no_data"]
    avg_ms = sum(r.ms for r in results if r.ok) / max(ok, 1)

    print("\n" + "=" * 60)
    print("SAMPLED BULK TEST (10,000 suburbs)")
    print("=" * 60)
    print(f"Tested:        {len(results)}")
    print(f"Elapsed:       {elapsed:.1f}s ({elapsed/len(results):.2f}s/suburb)")
    print(f"Successful:    {ok} ({100*ok/len(results):.1f}%)")
    print(f"With data:     {with_data} ({100*with_data/len(results):.1f}%)")
    print(f"No data:       {no_data} ({100*no_data/len(results):.1f}%)")
    print(f"Errors:        {errors}")
    print(f"Timeouts:      {timeouts}")
    print(f"Slow (>3s):    {slow}")
    print(f"Avg latency:   {avg_ms:.0f}ms (successful only)")

    print("\nPer state:")
    for st in sorted(state_stats):
        ss = state_stats[st]
        pct = 100 * ss["with_data"] / ss["tested"]
        print(f"  {st}: tested={ss['tested']}, with_data={ss['with_data']} ({pct:.1f}%), errors={ss['errors']}, timeouts={ss['timeouts']}, slow={ss['slow']}")

    print("\nIssue breakdown:", dict(issue_cat))

    # Examples
    print("\nSuburbs WITH data (sample):")
    for r in [x for x in results if x.count > 0][:8]:
        print(f"  {r.name}, {r.state}: {r.count} records ({r.ms:.0f}ms)")

    print("\nErrors (sample):")
    for r in [x for x in results if x.error][:5]:
        print(f"  {r.name}, {r.state}: {r.error[:80]}")

    report = Path(__file__).parent / "sampled_10k_test_report.json"
    with open(report, "w") as f:
        json.dump({
            "summary": {"tested": len(results), "with_data": with_data, "errors": errors, "timeouts": timeouts, "slow": slow, "no_data": no_data, "elapsed_sec": elapsed, "avg_ms": avg_ms},
            "state_stats": dict(state_stats),
            "issue_counter": dict(issue_cat),
        }, f, indent=2)
    print(f"\nReport: {report}")


if __name__ == "__main__":
    main()
