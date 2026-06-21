#!/usr/bin/env python3
"""pattern_detect — Φάση ⑤ του Renewal Cycle. ZERO-LLM.

Ένα μοτίβο δεν είναι κάτι που «αποφασίζω» — είναι κάτι που **επανεμφανίζεται**.
Όταν μια οντότητα/θέμα εμφανίζεται σε ≥N ξεχωριστά ίχνη (≥M διαφορετικές μέρες),
γίνεται υποψήφιο pattern: «αυτό το βλέπω ξανά». Καμία κρίση, καμία LLM κλήση —
καθαρή μέτρηση πάνω στα edges.

Το pattern_detect ΔΕΝ γράφει το pattern· το **προτείνει**. Η διατύπωση («τι
σημαίνει αυτή η επανάληψη») γεννιέται query-time ή από ανθρώπινη ματιά — ποτέ
παγωμένη εδώ. Συντεταγμένες επανάληψης, όχι νόημα.

Usage:
    python3 pattern_detect.py --edges <edges.json> [--min-count 3] [--min-days 2] [--json]
    python3 pattern_detect.py --reflective <dir> [...]
"""
from __future__ import annotations
import sys, os, json, argparse
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import edge_extract as ee


def detect(edges: list[dict], min_count: int = 3, min_days: int = 2) -> list[dict]:
    by_entity: dict[str, dict] = defaultdict(lambda: {"count": 0, "days": set(), "slugs": set()})
    for e in edges:
        ent = e["to_entity"]
        rec = by_entity[ent]
        rec["count"] += 1
        if e.get("date"):
            rec["days"].add(e["date"])
        rec["slugs"].add(e["from_slug"])
    out = []
    for ent, rec in by_entity.items():
        ndays = len(rec["days"])
        # ≥N εμφανίσεις ΚΑΙ ≥M διαφορετικές μέρες (όχι spike μιας μέρας)
        if rec["count"] >= min_count and ndays >= min_days:
            out.append({
                "theme": ent,
                "count": rec["count"],
                "distinct_days": ndays,
                "first_seen": min(rec["days"]) if rec["days"] else None,
                "last_seen": max(rec["days"]) if rec["days"] else None,
                "source_slugs": sorted(rec["slugs"]),
            })
    out.sort(key=lambda p: (p["distinct_days"], p["count"]), reverse=True)
    return out


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--edges")
    ap.add_argument("--reflective")
    ap.add_argument("--min-count", type=int, default=3)
    ap.add_argument("--min-days", type=int, default=2)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    if args.edges:
        edges = json.load(open(args.edges, encoding="utf-8"))["edges"]
    elif args.reflective:
        edges = ee.walk(args.reflective)
    else:
        ap.error("χρειάζεται --edges ή --reflective")

    patterns = detect(edges, args.min_count, args.min_days)
    if args.json:
        print(json.dumps({"count": len(patterns), "patterns": patterns},
                         ensure_ascii=False, indent=2))
    else:
        if not patterns:
            print("(κανένα υποψήφιο pattern ακόμα)")
        for p in patterns:
            print(f"↻ {p['theme']}  ({p['count']}× σε {p['distinct_days']} μέρες, "
                  f"{p['first_seen']}→{p['last_seen']})")
        print(f"\n{len(patterns)} υποψήφια patterns (προτάσεις, όχι κρίσεις)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
