#!/usr/bin/env python3
"""drift_gate — deterministic φύλακας φωνής (zero-LLM default).

Σαρώνει user-facing string για drift markers (academic/corporate/AI-slop/...).
Δεν γράφει — φλαγκάρει. Ο owner προσθέτει markers· optional cheap-model hook
(owner-enabled) κάνει βαθύτερη κρίση. Default: markers μόνο, μηδέν LLM.

Usage:
    echo "text" | python3 drift_gate.py            # exit 0 clean, 1 drift
    python3 drift_gate.py --check "text" --json
"""
from __future__ import annotations
import sys, re, json, argparse

# Deterministic drift markers (owner-extensible). Λίστα, όχι κρίση.
MARKERS = {
    "academic": [r"\bfurthermore\b", r"\bit is worth noting\b", r"\bin conclusion\b",
                 r"\bmoreover\b", r"\bnotably\b"],
    "corporate": [r"\bwe recommend\b", r"\bleverage\b", r"\butilize\b",
                  r"\bbest-in-class\b", r"\bseamless\b", r"\bsynerg"],
    "ai_slop": [r"\bas an ai\b", r"\bi'd be happy to\b", r"\bgreat question\b",
                r"\blet me break (this|it) down\b", r"\bdive into\b",
                r"\bit's important to (note|remember)\b"],
    "winking": [r"\barguably\b", r"\bin many ways\b", r"\bto a certain extent\b"],
}


def scan(text: str, extra: dict | None = None) -> list[dict]:
    hits = []
    groups = dict(MARKERS)
    if extra:
        for k, v in extra.items():
            groups.setdefault(k, []).extend(v)
    low = text.lower()
    for cat, pats in groups.items():
        for p in pats:
            m = re.search(p, low)
            if m:
                hits.append({"category": cat, "marker": m.group(0)})
    return hits


def is_clean(text: str, extra=None) -> bool:
    return not scan(text, extra)


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", help="κείμενο (αλλιώς stdin)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    text = args.check if args.check is not None else sys.stdin.read()
    hits = scan(text)
    if args.json:
        print(json.dumps({"clean": not hits, "hits": hits}, ensure_ascii=False, indent=2))
    else:
        if hits:
            for h in hits:
                print(f"DRIFT [{h['category']}]: {h['marker']}")
        else:
            print("clean")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
