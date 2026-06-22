#!/usr/bin/env python3
"""prune — Φάση ⑥ του Renewal Cycle. ZERO-LLM. Η λήθη με μνήμη.

Η λήθη δεν είναι διαγραφή — είναι **παύση ενεργής παρουσίας**. Ένα view γίνεται
orphan όταν ΚΑΝΕΝΑ υποστηρικτικό ίχνος δεν υπάρχει πια στο ρεύμα (τα slugs που
επικαλείται δεν βρίσκονται στα edges). Τότε δεν διαγράφεται — **μετακινείται στο
`views/_archive/`** με σφραγίδα `archived_at`. Ο recall_law μπορεί να το ξαναβρεί
αργότερα (ο φακός «έκπληξη»)· απλώς δεν είναι πια στο ενεργό προσκήνιο.

ΠΟΤΕ δεν αγγίζει live ίχνη. Μόνο compiled views. Move-by-archive: το view
αντιγράφεται στο _archive/ με σφραγίδα ΠΡΙΝ φύγει από το ενεργό
προσκήνιο — ποτέ απώλεια (ζει στο archive + git history).

Usage:
    python3 prune.py --views <dir> --edges <edges.json> [--apply] [--json]
    (default: dry-run — δείχνει τι ΘΑ αρχειοθετούσε, δεν κινεί τίποτα)
"""
from __future__ import annotations
import sys, os, re, json, shutil, argparse
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import edge_extract as ee
import stale_check


def known_slugs(edges: list[dict]) -> set[str]:
    """Όλα τα from_slug που υπάρχουν ακόμα στο ρεύμα."""
    return {e["from_slug"] for e in edges}


def find_orphans(views_dir: str, edges: list[dict]) -> list[dict]:
    alive = known_slugs(edges)
    orphans = []
    for root, _d, files in os.walk(views_dir):
        if os.path.basename(root) == "_archive":
            continue
        for fn in files:
            if not fn.endswith(".md") or fn.startswith("_"):
                continue
            v = stale_check.parse_view(os.path.join(root, fn))
            raw = v.get("supporting_slugs", "")
            # parse "[a, b]" ή "a, b"
            slugs = [s.strip().strip("'\"") for s in re.sub(r"[\[\]]", "", raw).split(",") if s.strip()]
            if not slugs:
                continue  # view χωρίς δηλωμένα slugs → δεν το κρίνουμε orphan (Iron Law: ≥1 edge ισχύει στη σύνθεση)
            still = [s for s in slugs if s in alive]
            if not still:  # ΚΑΝΕΝΑ υποστηρικτικό ίχνος δεν ζει πια
                orphans.append({"view": v["_slug"], "path": v["_path"],
                                "lost_slugs": slugs})
    return orphans


def archive(orphan: dict, views_dir: str) -> str:
    arch_dir = os.path.join(views_dir, "_archive")
    os.makedirs(arch_dir, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    dest = os.path.join(arch_dir, f"{orphan['view']}.{stamp}.md")
    # σφραγίδα archived_at στο frontmatter (append σχόλιο, χωρίς rewrite λογικής)
    text = open(orphan["path"], encoding="utf-8").read()
    text = f"<!-- archived_at: {stamp} — orphan: lost slugs {orphan['lost_slugs']} -->\n" + text
    with open(dest, "w", encoding="utf-8") as f:
        f.write(text)
    # το αντίγραφο ζει πλέον στο _archive/ με archived_at — σβήνουμε το
    # original από το ενεργό προσκήνιο (όχι απώλεια: υπάρχει στο archive + git history)
    os.remove(orphan["path"])
    return dest


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--views", required=True)
    ap.add_argument("--edges")
    ap.add_argument("--reflective")
    ap.add_argument("--apply", action="store_true", help="πραγματικά αρχειοθέτησε (default dry-run)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    if args.edges:
        edges = json.load(open(args.edges, encoding="utf-8"))["edges"]
    elif args.reflective:
        edges = ee.walk(args.reflective)
    else:
        ap.error("χρειάζεται --edges ή --reflective")

    orphans = find_orphans(args.views, edges)
    archived = []
    if args.apply:
        for o in orphans:
            dest = archive(o, args.views)
            archived.append({"view": o["view"], "archived_to": dest})

    if args.json:
        print(json.dumps({"orphan_count": len(orphans), "orphans": orphans,
                          "archived": archived, "applied": args.apply},
                         ensure_ascii=False, indent=2))
    else:
        for o in orphans:
            print(f"⚰ orphan: {o['view']}  (lost slugs: {o['lost_slugs']})")
        verb = "αρχειοθετήθηκαν" if args.apply else "ΘΑ αρχειοθετούνταν (dry-run)"
        print(f"\n{len(orphans)} orphan views {verb} → _archive/ (ποτέ διαγραφή)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
