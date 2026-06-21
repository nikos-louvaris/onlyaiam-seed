#!/usr/bin/env python3
"""resolve.py — alias → canonical entity name + type.

The seed ships with an EMPTY identity map: every entity resolves to itself with
type "unknown". The user wires aliases (people, projects, concepts) as they
accrue. Prints: "<canonical> <type>".
"""
import sys

# ALIASES: {alias_lower: (canonical, type)} — seed ships EMPTY.
ALIASES: dict[str, tuple[str, str]] = {}

def resolve(entity: str) -> tuple[str, str]:
    key = entity.strip().lower()
    if key in ALIASES:
        return ALIASES[key]
    return (entity.strip(), "unknown")

if __name__ == "__main__":
    ent = sys.argv[1] if len(sys.argv) > 1 else ""
    canon, etype = resolve(ent)
    print(f"{canon} {etype}")
