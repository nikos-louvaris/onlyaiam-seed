#!/usr/bin/env python3
"""stale_check — Φάση ③ του Renewal Engine. ZERO-LLM.

Το «κοίτα» για τη μνήμη: ποιο compiled view λέει κάτι που τα ίχνη δεν στηρίζουν
πια; Ένα view είναι STALE όταν υπάρχει ίχνος που το αφορά (mention του subject)
με ημερομηνία ΝΕΟΤΕΡΗ από το `compiled_at` του view. Τότε το view δεν είναι
πλέον in-line με την πραγματικότητα — μπαίνει στην ουρά για ξανα-ευθυγράμμιση.

Καμία κρίση, καμία LLM κλήση — καθαρά timestamp σύγκριση πάνω στα edges.

Usage:
    python3 stale_check.py --views <dir> --edges <edges.json> [--json]
    python3 stale_check.py --views <dir> --reflective <dir>   # χτίζει edges on the fly
"""
from __future__ import annotations
import sys, os, re, json, argparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import edge_extract as ee


def parse_view(path: str) -> dict:
    """Διάβασε frontmatter ενός view (μίνιμαλ YAML, stdlib μόνο)."""
    text = open(path, encoding="utf-8").read()
    m = re.search(r"^---\n(.*?)\n---", text, re.S)
    fm = {}
    if m:
        for line in m.group(1).splitlines():
            line = line.strip()
            if line.startswith("#") or ":" not in line:
                continue
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip()
    fm["_path"] = path
    fm["_slug"] = re.sub(r"\.md$", "", os.path.basename(path))
    return fm


def subject_tokens(subject: str) -> set[str]:
    """Το subject 'people/alex' ταιριάζει σε edges προς 'people/alex' ή 'Alex'."""
    toks = set()
    if subject:
        toks.add(subject)
        tail = subject.rsplit("/", 1)[-1]
        toks.add(tail)
        toks.add(tail.capitalize())
    return {t for t in toks if t}


def newest_evidence_date(edges: list[dict], subject: str) -> str | None:
    toks = subject_tokens(subject)
    dates = [e["date"] for e in edges
             if e.get("date") and e["to_entity"] in toks]
    return max(dates) if dates else None


def check(views_dir: str, edges: list[dict]) -> list[dict]:
    results = []
    for root, _d, files in os.walk(views_dir):
        if os.path.basename(root) == "_archive":
            continue  # αρχειοθετημένα views δεν είναι ενεργά — δεν κρίνονται για staleness
        for fn in files:
            if not fn.endswith(".md") or fn.startswith("_"):
                continue
            v = parse_view(os.path.join(root, fn))
            subject = v.get("subject", "")
            compiled_at = v.get("compiled_at", "")
            newest = newest_evidence_date(edges, subject)
            # STALE αν newest evidence > compiled_at (σύγκριση ISO date prefix)
            stale = bool(newest and compiled_at and newest > compiled_at[:10])
            results.append({
                "view": v["_slug"],
                "subject": subject,
                "compiled_at": compiled_at,
                "newest_evidence": newest,
                "stale": stale,
            })
    return results


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--views", required=True)
    ap.add_argument("--edges", help="προ-υπολογισμένο edges.json")
    ap.add_argument("--reflective", help="dir reflective files (χτίσε edges τώρα)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    if args.edges:
        edges = json.load(open(args.edges, encoding="utf-8"))["edges"]
    elif args.reflective:
        edges = ee.walk(args.reflective)
    else:
        ap.error("χρειάζεται --edges ή --reflective")

    results = check(args.views, edges)
    stale = [r for r in results if r["stale"]]
    if args.json:
        print(json.dumps({"stale_count": len(stale), "results": results},
                         ensure_ascii=False, indent=2))
    else:
        for r in results:
            mark = "STALE" if r["stale"] else "fresh"
            print(f"[{mark}] {r['view']}  (compiled {r['compiled_at'][:10]}, "
                  f"newest evidence {r['newest_evidence']})")
        print(f"\n{len(stale)} stale / {len(results)} views")
    return 0


if __name__ == "__main__":
    sys.exit(main())
