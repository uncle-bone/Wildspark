#!/usr/bin/env python3
"""Download Everloot's public WoW: Forever drop observations into a Lua pack.

The game addon cannot access the web, so this is run outside the game when the
bundled community-rate snapshot is refreshed. It preserves the dataset's
CC BY-SA attribution and reports the snapshot date in the generated file.
"""
import json
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

BASE = "https://everloot.app/api/rollups/drops"
PAGE_SIZE = 500


def fetch(offset):
    url = BASE + "?" + urlencode({"limit": PAGE_SIZE, "offset": offset})
    request = Request(url, headers={"User-Agent": "WildInfo crowd-rate pack builder"})
    with urlopen(request, timeout=30) as response:
        return json.load(response)


def lua_string(value):
    return json.dumps(str(value), ensure_ascii=True)


def main(destination):
    offset = 0
    total = None
    data_as_of = None
    rates = {}
    while total is None or offset < total:
        try:
            page = fetch(offset)
        except (HTTPError, URLError, TimeoutError) as error:
            raise SystemExit(f"Could not retrieve Everloot data: {error}") from error
        if page.get("unreachable"):
            raise SystemExit("Everloot reports that its drop data is unreachable")
        snapshot = page.get("dataAsOf")
        if not snapshot:
            raise SystemExit("Everloot response has no dataAsOf snapshot marker")
        if data_as_of is None:
            data_as_of = snapshot
            total = int(page.get("total", 0))
        elif snapshot != data_as_of:
            raise SystemExit("Everloot snapshot changed during paging; discard and retry")

        for row in page.get("rates", []):
            reporters = int(row.get("reporters", 0))
            windows = int(row.get("kills", 0))
            if not row.get("public") or reporters < 1 or windows < 1:
                continue
            # The API distinguishes creature sources from game objects. WildInfo's
            # unit tooltip hook can resolve creature GUIDs only, so exclude objects.
            if row.get("sourceNpcId") is None:
                continue
            npc_id = int(row["sourceNpcId"])
            item_id = int(row["itemId"])
            if npc_id < 1 or item_id < 1:
                continue
            rates.setdefault(npc_id, {})[item_id] = {
                "rate": float(row["rate"]) * 100,
                "drops": int(row["drops"]),
                "windows": windows,
                "reporters": reporters,
                "tier": str(row.get("tier", "reported")),
            }

        offset += int(page.get("limit", PAGE_SIZE))
        if offset < total:
            time.sleep(0.3)

    count = sum(len(items) for items in rates.values())
    output = Path(destination)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="\n") as stream:
        stream.write("-- Community observations from Everloot; distinct from WildInfo/Forever static data.\n")
        stream.write("-- Data from Everloot (https://everloot.app), CC BY-SA 4.0. See NOTICE.md.\n")
        stream.write("-- Changes: excluded game-object sources; converted the API fraction to percent; keyed records by NPC/item ID.\n")
        stream.write(f"-- Snapshot: {data_as_of}; {count} public source/item rates.\n")
        stream.write('-- API field "kills" counts recorded loot windows, not every creature killed.\n')
        stream.write("local _, addonNS = ...\n")
        stream.write("addonNS.WildInfoCrowdDropRates = {\n")
        stream.write(f"    dataAsOf = {lua_string(data_as_of)},\n")
        stream.write("    data = {\n")
        for npc_id in sorted(rates):
            stream.write(f"        [{npc_id}] = {{\n")
            for item_id in sorted(rates[npc_id]):
                row = rates[npc_id][item_id]
                stream.write(
                    f"            [{item_id}] = {{ rate = {row['rate']:.8g}, "
                    f"drops = {row['drops']}, windows = {row['windows']}, "
                    f"reporters = {row['reporters']}, tier = {lua_string(row['tier'])} }},\n"
                )
            stream.write("        },\n")
        stream.write("    },\n}\n")
    shrubbery = rates.get(248395, {}).get(247892)
    print(f"Wrote {count} NPC/item rates from {len(rates)} creatures; snapshot {data_as_of}.")
    print(f"Tainted Shrubbery / Verdant Leaves: {shrubbery or 'not present in this snapshot'}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: generate_wildinfo_crowd_rates.py <output-lua-path>")
    main(sys.argv[1])
