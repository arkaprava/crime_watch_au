#!/usr/bin/env python3
"""Build assets/data/australian_suburbs.json for local suburb autocomplete."""

from __future__ import annotations

import csv
import io
import json
import sys
import urllib.request
import zipfile
from pathlib import Path

csv.field_size_limit(sys.maxsize)

ROOT = Path(__file__).resolve().parents[1]
SERVICE_DATA = ROOT.parent / "crimewatch-service" / "data"
OUT = ROOT / "assets" / "data" / "australian_suburbs.json"
POSTCODES_CSV = ROOT / "tool" / "data" / "australian-postcodes.csv"
POSTCODES_URL = (
    "https://raw.githubusercontent.com/schappim/australian-postcodes/"
    "master/australian-postcodes.csv"
)
BOCSAR_ZIP = Path("/tmp/SuburbData.zip")


def state_from_postcode(postcode: str | None) -> str | None:
    """Infer Australian state/territory from a postcode when possible."""
    if not postcode:
        return None

    value = postcode.strip()
    if not value.isdigit():
        return None

    postcode_number = int(value)
    if 800 <= postcode_number <= 999:
        return "NT"
    if (
        2000 <= postcode_number <= 2599
        or 2619 <= postcode_number <= 2899
        or 2921 <= postcode_number <= 2999
    ):
        return "NSW"
    if 2600 <= postcode_number <= 2618 or 2900 <= postcode_number <= 2920:
        return "ACT"
    if 3000 <= postcode_number <= 3999 or 8000 <= postcode_number <= 8999:
        return "VIC"
    if 4000 <= postcode_number <= 4999 or 9000 <= postcode_number <= 9999:
        return "QLD"
    if 5000 <= postcode_number <= 5799 or 5800 <= postcode_number <= 5999:
        return "SA"
    if 6000 <= postcode_number <= 6797 or 6800 <= postcode_number <= 6999:
        return "WA"
    if 7000 <= postcode_number <= 7799 or 7800 <= postcode_number <= 7999:
        return "TAS"
    return None


def display_name(name: str) -> str:
    cleaned = name.strip()
    if cleaned.isupper():
        return cleaned.title()
    return cleaned


def add(
    entries: dict[str, dict],
    name: str,
    state: str,
    postcode: str | None = None,
    lat: float | None = None,
    lng: float | None = None,
) -> None:
    name = display_name(name)
    state = (state or "").strip().upper()
    if not name or not state:
        return

    key = f"{name.lower()}|{state}"
    record = {"n": name, "s": state}
    if postcode:
        record["p"] = str(postcode).strip()
    if lat is not None and lng is not None:
        record["lat"] = round(float(lat), 6)
        record["lng"] = round(float(lng), 6)

    existing = entries.get(key)
    if existing:
        for field in ("p", "lat", "lng"):
            if field in record and field not in existing:
                existing[field] = record[field]
    else:
        entries[key] = record


def ensure_postcodes_csv() -> Path:
    if POSTCODES_CSV.exists():
        return POSTCODES_CSV

    POSTCODES_CSV.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading postcodes CSV to {POSTCODES_CSV}...")
    urllib.request.urlretrieve(POSTCODES_URL, POSTCODES_CSV)
    return POSTCODES_CSV


def load_postcodes(entries: dict[str, dict]) -> None:
    csv_path = ensure_postcodes_csv()
    with csv_path.open() as handle:
        for row in csv.DictReader(handle):
            lat = lng = None
            if row.get("Lat") and row.get("Lon"):
                lat = float(row["Lat"])
                lng = float(row["Lon"])
            add(
                entries,
                row["Suburb"],
                row["State"],
                postcode=row.get("Postcode"),
                lat=lat,
                lng=lng,
            )


def load_nsw(entries: dict[str, dict]) -> None:
    if BOCSAR_ZIP.exists():
        with zipfile.ZipFile(BOCSAR_ZIP) as archive:
            with archive.open(archive.namelist()[0]) as handle:
                text = handle.read().decode("utf-8-sig")
        reader = csv.DictReader(io.StringIO(text))
        for row in reader:
            add(entries, row["Suburb"], "NSW")
        return

    fixture = SERVICE_DATA / "nsw/crime-statistics/suburb-data.csv"
    if not fixture.exists():
        return
    with fixture.open() as handle:
        for row in csv.DictReader(handle):
            add(entries, row["Suburb"], "NSW")


def load_sa(entries: dict[str, dict]) -> None:
    sa_csv = SERVICE_DATA / "sa/crime-statistics/crime-statistics-2024-25.csv"
    if not sa_csv.exists():
        return
    with sa_csv.open() as handle:
        for row in csv.DictReader(handle):
            postcode = row.get("Postcode - Incident")
            state = state_from_postcode(postcode) or "SA"
            add(
                entries,
                row["Suburb - Incident"],
                state,
                postcode=postcode,
            )


def load_geojson(entries: dict[str, dict]) -> None:
    geojson = SERVICE_DATA / "suburbs/australian-suburbs.geojson"
    if not geojson.exists():
        return

    data = json.loads(geojson.read_text())
    for feature in data.get("features", []):
        props = feature.get("properties", {})
        centroid = props.get("centroid")
        lat = lng = None
        if isinstance(centroid, list) and len(centroid) >= 2:
            lng, lat = centroid[0], centroid[1]
        add(
            entries,
            props.get("name", ""),
            props.get("state", ""),
            props.get("postcode"),
            lat,
            lng,
        )


def main() -> None:
    entries: dict[str, dict] = {}
    load_postcodes(entries)
    load_nsw(entries)
    load_sa(entries)
    load_geojson(entries)

    result = sorted(entries.values(), key=lambda item: (item["n"].lower(), item["s"]))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(result, separators=(",", ":")))
    print(f"Wrote {len(result)} suburbs to {OUT}")


if __name__ == "__main__":
    main()
