#!/usr/bin/env python3
"""edge_extract — Στρώμα 1β του Renewal Engine. ZERO-LLM.

Σαρώνει reflective markdown και βγάζει edges στο index. Ένα edge λέει «αυτό το
ίχνος αναφέρει αυτή την οντότητα, αυτή τη μέρα» — ΣΥΝΤΕΤΑΓΜΕΝΕΣ, ΟΧΙ ΝΟΗΜΑ.
Κανένα typed verb (works_at/invested_in): η ερμηνεία παγώνει, οι συντεταγμένες όχι.
Το νόημα της γειτονίας γεννιέται query-time από τον recall_law.

3 regexes, μηδέν LLM tokens:
  1. markdown links     [label](path/slug)
  2. wikilinks          [[path/slug|label]]  ή  [[slug]]
  3. mentions           Κεφαλαία-runs / @handles  (πιθανές οντότητες)

Usage:
    python3 edge_extract.py <dir> [--out edges/edges.json] [--json]
"""
from __future__ import annotations
import sys, os, re, json, argparse
from datetime import datetime

# --- 3 patterns (zero-LLM) ---
RE_MDLINK   = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
RE_WIKILINK = re.compile(r"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]")
# Κεφαλαία-runs (Latin + Greek): πιθανές οντότητες. @handles.
RE_MENTION  = re.compile(
    r"@(\w+)|(\b[A-ZΑ-ΩΆ-Ώ][\wά-ώΰΐ]+(?:\s+[A-ZΑ-ΩΆ-Ώ][\wά-ώΰΐ]+)*)"
)
# Λέξεις-θόρυβος που ξεκινούν πρόταση αλλά δεν είναι οντότητες (επεκτάσιμο από owner).
STOPWORDS = set()


def slug_from_path(p: str) -> str:
    p = p.strip().strip("/")
    p = re.sub(r"\.md$", "", p)
    return p


def date_from_filename(fn: str) -> str | None:
    m = re.search(r"(\d{4}-\d{2}-\d{2})", fn)
    return m.group(1) if m else None


def _is_sentence_start(text: str, idx: int) -> bool:
    """True αν η θέση idx είναι αρχή γραμμής/πρότασης. Zero-LLM, θεσιακό."""
    j = idx - 1
    while j >= 0 and text[j] in " \t#>*-_":
        j -= 1
    return j < 0 or text[j] in ".!?;:\n"


def extract_from_text(text: str, src_slug: str, date: str | None) -> list[dict]:
    edges: list[dict] = []
    seen: set[tuple] = set()

    def add(to_entity: str, kind: str):
        to_entity = to_entity.strip()
        if not to_entity or to_entity in STOPWORDS:
            return
        key = (src_slug, to_entity, kind)
        if key in seen:
            return
        seen.add(key)
        edges.append({
            "from_slug": src_slug,
            "to_entity": to_entity,
            "date": date,
            "kind": kind,          # mention μόνο — ΟΧΙ typed verb
        })

    for label, path in RE_MDLINK.findall(text):
        add(slug_from_path(path), "link")
    for path, label in RE_WIKILINK.findall(text):
        add(slug_from_path(path), "wikilink")
    for m in RE_MENTION.finditer(text):
        handle, capword = m.group(1), m.group(2)
        if handle:
            add(handle, "mention")
        elif capword:
            # Deterministic anti-noise: μονή κεφαλαία λέξη σε αρχή πρότασης
            # = γραμματική, όχι οντότητα. Multi-word ή mid-sentence → κρατάμε.
            # Καμία εφεύρεση — μόνο ό,τι υπάρχει. Ο owner ρυθμίζει με STOPWORDS.
            single = " " not in capword
            if single and _is_sentence_start(text, m.start(2)):
                continue
            add(capword, "mention")
    return edges


def walk(directory: str) -> list[dict]:
    all_edges: list[dict] = []
    for root, _dirs, files in os.walk(directory):
        for fn in files:
            if not fn.endswith(".md"):
                continue
            full = os.path.join(root, fn)
            rel = os.path.relpath(full, directory)
            src_slug = slug_from_path(rel)
            date = date_from_filename(fn)
            text = open(full, encoding="utf-8").read()
            all_edges.extend(extract_from_text(text, src_slug, date))
    return all_edges


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("directory")
    ap.add_argument("--out", default=None, help="γράψε edges JSON εδώ")
    ap.add_argument("--json", action="store_true", help="τύπωσε JSON στο stdout")
    args = ap.parse_args(argv)

    edges = walk(args.directory)
    payload = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "source_dir": args.directory,
        "count": len(edges),
        "edges": edges,
    }
    if args.out:
        os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
    if args.json or not args.out:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
