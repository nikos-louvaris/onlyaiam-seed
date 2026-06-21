#!/usr/bin/env python3
"""query.py — pull fresh signals about an entity from every connected source.

The seed ships with NO sources wired. This stub emits an empty signal envelope;
the user adds source adapters (memory grep, substrate traversal, git log, any
connected service) that append to `signals`. The shape is the gift: pull fresh,
never read a cached synthesis.

Usage: query.py <canonical> <type>   → prints a JSON envelope on stdout.
"""
import json
import sys

def gather(canon: str, etype: str) -> dict:
    signals: list[dict] = []
    # --- SOURCE ADAPTERS (seed ships EMPTY — wire your own) ---
    # signals += grep_memory(canon)
    # signals += traverse_substrate(canon)
    # signals += git_log_touching(canon)
    return {"entity": canon, "type": etype, "signals": signals}

if __name__ == "__main__":
    canon = sys.argv[1] if len(sys.argv) > 1 else ""
    etype = sys.argv[2] if len(sys.argv) > 2 else "unknown"
    print(json.dumps(gather(canon, etype), ensure_ascii=False))
