#!/usr/bin/env python3
"""synthesize.py — synthesize a live state reading from gathered signals, NOW.

Reads the JSON envelope from query.py on stdin, synthesizes a present-tense
reading, prints it, and forgets. NOTHING is stored — this is the recall law
(index ≠ meaning) in executable form.

The seed ships a passthrough: with no signals and no LLM wired, it states
honestly that there is nothing yet. The user wires their own model call where
marked. Flags: --deep (more thorough), --fast (cheaper).
"""
import json
import sys

def synthesize(env: dict, deep: bool, fast: bool) -> str:
    entity = env.get("entity", "?")
    signals = env.get("signals", [])
    if not signals:
        return (f"state-of {entity}: no signals yet. The hippocampus is empty — "
                f"nothing has been lived about this entity. (Wire sources in "
                f"state_of/query.py as they accrue.)")
    # --- LLM SYNTHESIS (seed ships passthrough — wire your model here) ---
    # return call_model(entity, signals, deep=deep, fast=fast)
    return json.dumps({"entity": entity, "signal_count": len(signals),
                       "note": "raw signals (no model wired yet)"},
                      ensure_ascii=False, indent=2)

if __name__ == "__main__":
    deep = "--deep" in sys.argv
    fast = "--fast" in sys.argv
    raw = sys.stdin.read().strip()
    env = json.loads(raw) if raw else {"entity": "?", "signals": []}
    print(synthesize(env, deep, fast))
