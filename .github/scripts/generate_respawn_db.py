#!/usr/bin/env python3
"""Generate WildInfo's Classic NPC respawn reference from the CMaNGOS SQLite DB.

The addon uses these as clearly labeled Classic estimates. Local and peer
observations remain separate and take precedence. This file contains only the
most common min/max spawn-time pair per creature ID.
"""
import sqlite3
import sys
from pathlib import Path

MAX_SECONDS = 7 * 24 * 60 * 60


def databases(root):
    for path in sorted(Path(root).rglob("*")):
        if not path.is_file():
            continue
        try:
            with path.open("rb") as stream:
                if stream.read(16) == b"SQLite format 3\x00":
                    yield path
        except OSError:
            continue


def quote(name):
    return '"' + name.replace('"', '""') + '"'


def extract(path):
    connection = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
    try:
        tables = [row[0] for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type='table'")]
        for table in tables:
            columns = {row[1].lower(): row[1] for row in
                       connection.execute(f"PRAGMA table_info({quote(table)})")}
            id_col = columns.get("id") or columns.get("entry")
            min_col = columns.get("spawntimesecsmin")
            max_col = columns.get("spawntimesecsmax")
            if id_col and min_col and max_col:
                sql = (f"SELECT {quote(id_col)}, {quote(min_col)}, {quote(max_col)}, COUNT(*) "
                       f"FROM {quote(table)} GROUP BY 1, 2, 3")
                return list(connection.execute(sql))
            single = columns.get("spawntimesecs")
            if id_col and single:
                sql = (f"SELECT {quote(id_col)}, {quote(single)}, {quote(single)}, COUNT(*) "
                       f"FROM {quote(table)} GROUP BY 1, 2")
                return list(connection.execute(sql))
        return None
    finally:
        connection.close()


def main(root):
    source = None
    rows = None
    for path in databases(root):
        candidate = extract(path)
        if candidate:
            source, rows = path.name, candidate
            break
    if rows is None:
        raise SystemExit("No SQLite database with creature spawn-time columns was found")

    # Match the most frequent timer pair for each creature, as individual spawn
    # points can differ. On a tie prefer the wider/longer interval.
    choices = {}
    for npc_id, minimum, maximum, count in rows:
        try:
            npc_id, minimum, maximum, count = map(int, (npc_id, minimum, maximum, count))
        except (TypeError, ValueError):
            continue
        if npc_id < 1 or minimum < 1 or maximum < minimum or maximum > MAX_SECONDS:
            continue
        pair = (minimum, maximum)
        current = choices.get(npc_id)
        if current is None or (count, maximum, minimum) > (current[0], current[2], current[1]):
            choices[npc_id] = (count, minimum, maximum)

    if len(choices) < 1000:
        raise SystemExit(f"Refusing to write suspiciously small reference set ({len(choices)} NPCs)")

    output = [
        "-- Generated from the current CMaNGOS Classic SQLite world database.",
        "-- For each creature ID this records the most common spawn timer pair across its spawn points.",
        "-- These are Classic references, not verified WoW Forever server timers.",
        "-- See NOTICE.md, CMANGOS_LICENSE.txt, and CMANGOS_COPYRIGHT.txt.",
        "local _, addonNS = ...",
        "addonNS.WildInfoRespawnDB = {",
    ]
    for npc_id in sorted(choices):
        _, minimum, maximum = choices[npc_id]
        output.append(f"    [{npc_id}] = {{ min = {minimum}, max = {maximum} }},")
    output.append("}")
    destination = Path("Wildspark/Modules/WildDrops/RespawnData.lua")
    destination.write_text("\n".join(output) + "\n", encoding="utf-8", newline="\n")
    print(f"Generated {len(choices)} Classic NPC respawn records from {source} into {destination}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: generate_respawn_db.py <unzipped-database-directory>")
    main(sys.argv[1])
