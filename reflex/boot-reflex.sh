#!/bin/bash
# boot-reflex.sh — run health checks in sequence at session start.
# Silent stdout = OK. Non-zero exit = at least one check raised an alert.
#
# This is the IMMUNE SYSTEM (mechanical, runs the same every time), NOT the
# pulse (which sees fresh each time, lives in pulse/PULSE.md). One mechanical,
# one living. Memory is not a reflex, so the reflex is a script — not an
# instruction an agent is told to "remember to run".
#
# The seed ships this EMPTY: the registry below has no checks. The agent/user
# wires its own guards as they accrue (each scar that earns a reflex lands here).
set -u
WORKSPACE="${WORKSPACE:-$HOME/.openclaw/workspace}"
cd "$WORKSPACE" || { echo "boot-reflex: cannot cd to $WORKSPACE"; exit 99; }

ANY_ALERT=0; OUTPUT=""

# run_check "Label" "command..." — run it, append salient output, flag on non-zero.
run_check() {
  local label="$1"; shift
  local out; out=$("$@" 2>&1); local rc=$?
  if [ $rc -ne 0 ] || [ -n "$out" ]; then
    OUTPUT+="• ${label}: ${out}
"
    [ $rc -ne 0 ] && ANY_ALERT=1
  fi
}

# --- REGISTRY (seed ships EMPTY — wire your own; examples below) ---
# run_check "memory committed" bash reflex/auto-commit-memory.sh
# run_check "no stale plans"   bash reflex/verify-no-stale.sh
# run_check "bootstrap intact" bash reflex/integrity-check.sh

# Principles:
#   correctness = hard fail · performance = soft warn (scales with size)
#   alert-fatigue IS a disease: a guard that cries on healthy data = a bug
#   the most dangerous blind spot = the one you label "OK/static" to clean the report

[ -n "$OUTPUT" ] && printf "🫀 boot-reflex — %s\n\n%s" "$(date '+%F %T %Z')" "$OUTPUT"
exit $ANY_ALERT
