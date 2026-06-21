#!/usr/bin/env python3
"""
recall_law.py — the single-source recall law of the seed.

ONE recall law, MANY lenses (profiles). The recall weight of any trace is the
SAME formula everywhere:

    weight = base * decay * recency * text_score

What changes between callers is not the law but the *lens* — a named profile
that fixes how `base` is computed. There is one law; the lenses are the many
doors onto it:

  - lens="field" (default): base is ALWAYS 1.0. No prior. All traces are equal;
    only time (decay), recency, and match (text_score) weigh. The purest
    reading — the 100% door. This is the seed's default.

  - lens="reflective": base = MODE_PRIOR.get(mode, 1.0). A prior is applied so
    higher-mode (more reflective) traces carry more weight. Used only inside
    reflective dialogue, behind an activation gate.

  - lens="surprise": opt-in graph re-ranker (the forgotten connection that
    surprises you while keeping its difference). Behind two gates, OFF by
    default. Ships as the same law; the spread step is wired by the user.

Pure stdlib only (math, datetime); no external deps. The seed ships this with
ZERO traces — the law knows how to weigh by time, it simply has nothing to
weigh yet. The hippocampus fills as the person lives.

ALL parameters below are DEFAULTS, meant to move to config — never hardcode a
person's half-life into the law.
"""
from __future__ import annotations

import math
from datetime import datetime, timezone

# --- Parameters (CONFIG defaults, not law) ---
HALF_LIFE_DAYS = 180          # 6 months
RECENCY_BOOST_30D = 1.5
RECENCY_BOOST_90D = 1.2
MODE_PRIOR = {1: 1.0, 2: 1.4, 3: 2.0}  # reflective lens only; field ignores it


def _parse_dt(value):
    """Parse a timestamp (str ISO or datetime) into a tz-aware UTC datetime.
    Returns None if value is falsy or unparseable."""
    if not value:
        return None
    if isinstance(value, str):
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    else:
        dt = value
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def recall_weight(row, now: datetime, lens: str = "field") -> tuple[float, dict]:
    """The single recall law: weight = base * decay * recency * text_score.

    Args:
        row: a mapping describing a trace. Read via .get():
             - "mode": int mode (used only by the "reflective" lens)
             - "when": original timestamp (str ISO or datetime)
             - "last_activated_at": last-activation timestamp
             - "text_score": float match score (default 1.0)
        now: tz-aware "now" to measure decay/recency against.
        lens: which profile fixes `base`:
              - "field" (default): base = 1.0 always (no prior)
              - "reflective": base = MODE_PRIOR.get(mode, 1.0)
              - "surprise": base = 1.0 here; spread re-rank applied downstream

    Returns:
        (final_weight, breakdown).
    """
    mode = row.get("mode")
    when = row.get("when")

    # --- base (the only thing the lens changes) ---
    if lens == "reflective":
        base = MODE_PRIOR.get(mode, 1.0)
    else:  # "field", "surprise", and any unknown lens → purest reading
        base = 1.0

    # --- decay since last_activated_at if set, else since "when" ---
    decay_anchor = row.get("last_activated_at") or when
    decay = 1.0
    if decay_anchor:
        try:
            anchor = _parse_dt(decay_anchor)
            days = (now - anchor).total_seconds() / 86400
            if days > 0:
                decay = math.exp(-math.log(2) * days / HALF_LIFE_DAYS)
        except Exception:
            decay = 1.0

    # --- recency boost on "when" only ---
    # Future-dated moments (d < 0, e.g. an upcoming calendar event) must NOT
    # receive the recency boost, or a far-future instance ranks as freshest.
    recency = 1.0
    if when:
        try:
            w = _parse_dt(when)
            d = (now - w).total_seconds() / 86400
            if 0 <= d <= 30:
                recency = RECENCY_BOOST_30D
            elif 30 < d <= 90:
                recency = RECENCY_BOOST_90D
        except Exception:
            pass

    text_score = float(row.get("text_score", 1.0))

    final = base * decay * recency * text_score
    return final, {
        "base": base,
        "decay": round(decay, 4),
        "recency": recency,
        "text_score": text_score,
        "final": round(final, 4),
        "lens": lens,
    }


if __name__ == "__main__":
    # Self-test: one synthetic row read through every lens.
    now = datetime(2026, 1, 1, tzinfo=timezone.utc)
    row = {
        "mode": 3,
        "when": "2025-12-07T00:00:00Z",            # ~25 days ago → 30d boost (1.5)
        "last_activated_at": "2025-10-01T00:00:00Z",  # ~92 days ago → decay
        "text_score": 0.8,
    }

    print("recall_law.py self-test — ONE law, MANY lenses")
    print(f"now = {now.isoformat()}")
    print(f"row = {row}\n")

    for lens in ("field", "reflective", "surprise"):
        final, bd = recall_weight(row, now, lens=lens)
        print(f"lens={lens!r:12} final={final:.4f}  breakdown={bd}")
