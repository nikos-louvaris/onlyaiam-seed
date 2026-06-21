#!/usr/bin/env python3
"""recall_offer — Στρώμα 3α: ο υποδεικτικός τρόπος. ZERO-LLM (extract/resolve).

Όταν ο σπόρος μιλά, ανασύρει ΕΘΕΛΟΝΤΙΚΑ σχετικά pointers από το rolling
conversation window — confidence-gated, cap 3. Ζυγίζει με recall_law (freshness),
ώστε stale views να ξεθωριάζουν. Προσφέρει POINTERS + confidence + freshness —
ΠΟΤΕ τελικές απαντήσεις (το όριο της φάσης ④).

Privacy: το feedback log κρατά μόνο deterministic template string — ΠΟΤΕ raw
conversation. Ο αποδέκτης αποφασίζει αν θα ανοίξει το pointer.

Pipeline: extract entities → resolve (edges/aliases, honest confidence) →
gate (min_confidence, cap) → recall_law freshness → offer.

Usage:
    printf 'user: ...\\nassistant: ...\\n' | python3 recall_offer.py \\
        --views <dir> --edges <edges.json> [--min-confidence 0.7] [--max 3] [--json]
"""
from __future__ import annotations
import sys, os, re, json, argparse
from datetime import datetime, timezone

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "memory"))
import recall_law
import stale_check  # reuse parse_view, subject_tokens

RE_HANDLE = re.compile(r"@(\w+)")
RE_CAP = re.compile(r"\b[A-ZΑ-ΩΆ-Ώ][\wά-ώΰΐ]+(?:\s+[A-ZΑ-ΩΆ-Ώ][\wά-ώΰΐ]+)*")

# honest confidence per resolve arm (gbrain-inspired)
CONF = {"alias": 0.9, "exact_title": 0.8, "slug_suffix": 0.6}
SALIENCE_BONUS = 0.05  # mentioned in ≥2 turns ή στο newest turn


def extract_entities(transcript: str) -> dict[str, dict]:
    """Zero-LLM: capitalized runs + @handles, με recency/frequency salience."""
    lines = [l for l in transcript.splitlines() if l.strip()]
    n = len(lines)
    ents: dict[str, dict] = {}
    for i, line in enumerate(lines):
        is_newest = (i == n - 1)
        for h in RE_HANDLE.findall(line):
            e = ents.setdefault(h, {"count": 0, "newest": False})
            e["count"] += 1; e["newest"] |= is_newest
        for c in RE_CAP.findall(line):
            # drop role prefixes like "User"/"Assistant"
            if c.lower() in ("user", "assistant", "system"):
                continue
            e = ents.setdefault(c, {"count": 0, "newest": False})
            e["count"] += 1; e["newest"] |= is_newest
    return ents


def load_views(views_dir: str) -> list[dict]:
    out = []
    if not os.path.isdir(views_dir):
        return out
    for root, _d, files in os.walk(views_dir):
        if os.path.basename(root) == "_archive":
            continue  # archived views δεν προσφέρονται ως ενεργά pointers
        for fn in files:
            if fn.endswith(".md") and not fn.startswith("_"):
                out.append(stale_check.parse_view(os.path.join(root, fn)))
    return out


def resolve(entity: str, views: list[dict]) -> list[dict]:
    """Match entity → views, με honest confidence ανά arm."""
    hits = []
    for v in views:
        subject = v.get("subject", "")
        toks = stale_check.subject_tokens(subject)
        arm = None
        if entity == subject:
            arm = "exact_title"
        elif entity in toks:
            arm = "alias"
        elif subject.endswith("/" + entity.lower()):
            arm = "slug_suffix"
        if arm:
            hits.append({"view": v, "arm": arm, "confidence": CONF[arm]})
    return hits


def freshness(view: dict) -> float:
    """recall_law weight: stale view (παλιό compiled_at) ξεθωριάζει."""
    row = {"when": view.get("compiled_at"), "text_score": 1.0}
    now = datetime.now(timezone.utc)
    w, _ = recall_law.recall_weight(row, now, lens="field")
    return round(w, 4)


def offer(transcript: str, views_dir: str, min_conf: float, cap: int,
          prior: set[str] | None = None) -> list[dict]:
    prior = prior or set()
    ents = extract_entities(transcript)
    views = load_views(views_dir)
    cands: list[dict] = []
    for entity, meta in ents.items():
        for hit in resolve(entity, views):
            conf = hit["confidence"]
            if meta["count"] >= 2 or meta["newest"]:
                conf = min(1.0, conf + SALIENCE_BONUS)
            slug = hit["view"]["_slug"]
            if slug in prior:
                continue
            if conf < min_conf:
                continue
            cands.append({
                "pointer": hit["view"].get("subject", slug),
                "view_slug": slug,
                "confidence": round(conf, 3),
                "freshness": freshness(hit["view"]),
                "arm": hit["arm"],
                # ΟΧΙ το περιεχόμενο — pointer μόνο. Η σύνθεση γεννιέται query-time.
            })
    # rank: confidence * freshness (φρέσκο + σίγουρο πρώτα)
    cands.sort(key=lambda c: c["confidence"] * c["freshness"], reverse=True)
    # dedup ανά view_slug
    seen, out = set(), []
    for c in cands:
        if c["view_slug"] in seen:
            continue
        seen.add(c["view_slug"]); out.append(c)
        if len(out) >= cap:
            break
    return out


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--views", required=True)
    ap.add_argument("--edges", help="(reserved· resolve γίνεται μέσω views εδώ)")
    ap.add_argument("--min-confidence", type=float, default=0.7)
    ap.add_argument("--max", type=int, default=3)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    transcript = sys.stdin.read()
    offers = offer(transcript, args.views, args.min_confidence, args.max)
    if args.json:
        print(json.dumps({"offers": offers}, ensure_ascii=False, indent=2))
    else:
        if not offers:
            print("(κανένα pointer — σιωπή είναι απάντηση)")
        for o in offers:
            print(f"→ {o['pointer']}  [conf {o['confidence']}, fresh {o['freshness']}, {o['arm']}]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
