#!/usr/bin/env python3
"""Bulk suburb crime stats test — mirrors the Flutter app's GraphQL queries."""

import json
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
MIN_SUBURBS = 10_000
CONCURRENCY = 8
TIMEOUT_SEC = 15
SAMPLE_NEAR_RADIUS_KM = 5.0

CRIME_INCIDENTS_QUERY = """
query CrimeIncidents($city: String, $state: String, $limit: Int) {
  crimeIncidents(city: $city, state: $state, limit: $limit) {
    id title offenceCount granularity geocodeStatus
    location { city state }
  }
}
"""

CRIMES_NEAR_QUERY = """
query CrimesNearLocation($latitude: Float!, $longitude: Float!, $radiusKm: Float!, $state: String) {
  crimesNearLocation(latitude: $latitude, longitude: $longitude, radiusKm: $radiusKm, state: $state) {
    id title offenceCount granularity geocodeStatus
    location { city state }
  }
}
"""


@dataclass
class SuburbResult:
    name: str
    state: str
    postcode: str | None
    lat: float | None
    lng: float | None
    city_query_ok: bool = False
    city_query_ms: float = 0
    city_count: int = 0
    city_error: str | None = None
    near_query_ok: bool = False
    near_query_ms: float = 0
    near_count: int = 0
    near_error: str | None = None
    issues: list[str] = field(default_factory=list)


def graphql(query: str, variables: dict) -> tuple[dict | None, float, str | None]:
    payload = json.dumps({"query": query, "variables": variables}).encode()
    req = urllib.request.Request(
        GRAPHQL_URL,
        data=payload,
        headers={"Content-Type": "application/json", "X-API-Key": API_KEY},
        method="POST",
    )
    start = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SEC) as resp:
            body = json.loads(resp.read())
            elapsed = (time.monotonic() - start) * 1000
            if "errors" in body:
                return body.get("data"), elapsed, "; ".join(
                    e.get("message", str(e)) for e in body["errors"]
                )
            return body.get("data"), elapsed, None
    except urllib.error.HTTPError as e:
        elapsed = (time.monotonic() - start) * 1000
        return None, elapsed, f"HTTP {e.code}: {e.read().decode()[:200]}"
    except Exception as e:
        elapsed = (time.monotonic() - start) * 1000
        return None, elapsed, str(e)


def test_suburb(entry: dict) -> SuburbResult:
    name = entry.get("n", "")
    state = entry.get("s", "")
    result = SuburbResult(
        name=name,
        state=state,
        postcode=entry.get("p"),
        lat=entry.get("lat"),
        lng=entry.get("lng"),
    )

    # Test crimeIncidents (what app uses on suburb selection)
    data, ms, err = graphql(CRIME_INCIDENTS_QUERY, {"city": name, "state": state, "limit": 50})
    result.city_query_ms = ms
    if err:
        result.city_error = err
        result.issues.append(f"city_query_failed: {err}")
    else:
        result.city_query_ok = True
        incidents = (data or {}).get("crimeIncidents") or []
        result.city_count = len(incidents)
        if ms > 5000:
            result.issues.append(f"slow_city_query: {ms:.0f}ms")
        for inc in incidents:
            loc = inc.get("location") or {}
            if loc.get("city", "").lower() != name.lower():
                result.issues.append(f"city_mismatch: expected {name}, got {loc.get('city')}")
                break
            if loc.get("state", "").upper() != state.upper():
                result.issues.append(f"state_mismatch: expected {state}, got {loc.get('state')}")
                break

    # Test crimesNearLocation if coords available
    if result.lat is not None and result.lng is not None:
        data, ms, err = graphql(
            CRIMES_NEAR_QUERY,
            {
                "latitude": result.lat,
                "longitude": result.lng,
                "radiusKm": SAMPLE_NEAR_RADIUS_KM,
                "state": state,
            },
        )
        result.near_query_ms = ms
        if err:
            result.near_error = err
            result.issues.append(f"near_query_failed: {err}")
        else:
            result.near_query_ok = True
            result.near_count = len((data or {}).get("crimesNearLocation") or [])
            if ms > 5000:
                result.issues.append(f"slow_near_query: {ms:.0f}ms")
    else:
        result.issues.append("missing_coordinates")

    return result


def main():
    with open(SUBURBS_PATH) as f:
        suburbs = json.load(f)

    print(f"Loaded {len(suburbs)} suburbs from asset")
    if len(suburbs) < MIN_SUBURBS:
        print(f"WARNING: fewer than {MIN_SUBURBS} suburbs in asset")

    # Test all suburbs
    results: list[SuburbResult] = []
    issue_counter: Counter = Counter()
    state_stats: dict[str, dict] = defaultdict(lambda: {
        "tested": 0, "with_data": 0, "errors": 0, "no_coords": 0, "timeouts": 0
    })

    start_all = time.monotonic()
    completed = 0

    with ThreadPoolExecutor(max_workers=CONCURRENCY) as pool:
        futures = {pool.submit(test_suburb, s): s for s in suburbs}
        for fut in as_completed(futures):
            r = fut.result()
            results.append(r)
            completed += 1
            ss = state_stats[r.state]
            ss["tested"] += 1
            if r.city_count > 0 or r.near_count > 0:
                ss["with_data"] += 1
            if r.city_error or r.near_error:
                ss["errors"] += 1
            if r.lat is None:
                ss["no_coords"] += 1
            if r.city_error and "timed out" in (r.city_error or "").lower():
                ss["timeouts"] += 1
            for issue in r.issues:
                issue_counter[issue.split(":")[0]] += 1
            if completed % 500 == 0:
                elapsed = time.monotonic() - start_all
                print(f"  Progress: {completed}/{len(suburbs)} ({elapsed:.0f}s)", flush=True)

    total_elapsed = time.monotonic() - start_all

    # Summary
    with_data = sum(1 for r in results if r.city_count > 0 or r.near_count > 0)
    city_errors = sum(1 for r in results if r.city_error)
    near_errors = sum(1 for r in results if r.near_error)
    no_coords = sum(1 for r in results if r.lat is None)
    slow = sum(1 for r in results if r.city_query_ms > 5000 or r.near_query_ms > 5000)
    timeouts = sum(1 for r in results if r.city_error and "timed out" in r.city_error.lower())

    print("\n" + "=" * 60)
    print("BULK SUBURB TEST SUMMARY")
    print("=" * 60)
    print(f"Suburbs tested:     {len(results)}")
    print(f"Total time:         {total_elapsed:.1f}s")
    print(f"With crime data:    {with_data} ({100*with_data/len(results):.1f}%)")
    print(f"No crime data:      {len(results) - with_data} ({100*(len(results)-with_data)/len(results):.1f}%)")
    print(f"City query errors:  {city_errors}")
    print(f"Near query errors:  {near_errors}")
    print(f"Missing coords:     {no_coords}")
    print(f"Slow queries (>5s): {slow}")
    print(f"Timeouts:           {timeouts}")

    print("\nPer-state breakdown:")
    for state in sorted(state_stats):
        ss = state_stats[state]
        pct = 100 * ss["with_data"] / ss["tested"] if ss["tested"] else 0
        print(f"  {state}: tested={ss['tested']}, with_data={ss['with_data']} ({pct:.1f}%), errors={ss['errors']}, no_coords={ss['no_coords']}")

    print("\nIssue categories:")
    for issue, count in issue_counter.most_common(20):
        print(f"  {issue}: {count}")

    # Sample suburbs with data
    sample_with = [r for r in results if r.city_count > 0][:5]
    print("\nSample suburbs WITH data:")
    for r in sample_with:
        print(f"  {r.name}, {r.state}: city={r.city_count}, near={r.near_count}")

    # Sample errors
    sample_errors = [r for r in results if r.city_error][:5]
    if sample_errors:
        print("\nSample errors:")
        for r in sample_errors:
            print(f"  {r.name}, {r.state}: {r.city_error}")

    # Write detailed report
    report_path = Path(__file__).parent / "bulk_suburb_test_report.json"
    report = {
        "summary": {
            "tested": len(results),
            "with_data": with_data,
            "city_errors": city_errors,
            "near_errors": near_errors,
            "no_coords": no_coords,
            "slow": slow,
            "timeouts": timeouts,
            "elapsed_sec": total_elapsed,
        },
        "state_stats": dict(state_stats),
        "issue_counter": dict(issue_counter),
        "suburbs_with_issues": [
            {"name": r.name, "state": r.state, "issues": r.issues, "city_error": r.city_error}
            for r in results if r.issues
        ][:500],
    }
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)
    print(f"\nDetailed report: {report_path}")


if __name__ == "__main__":
    main()
