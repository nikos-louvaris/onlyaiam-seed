#!/usr/bin/env bash
# cycle.sh — thin harness για τον Renewal Cycle. Τρέχει τις 6 φάσεις.
# Λογική/κρίση/Iron Law ζουν στο CYCLE.md. Εδώ μόνο η ενορχήστρωση.
#
# Usage:
#   cycle.sh --reflective <dir> --views <dir> [--edges-out <f>]
#            [--dry-run] [--synthesize] [--max-usd N] [--ignore-quiet-hours]
#
# Defaults: dry-run-safe, zero-LLM (φάση ④ = flag-only εκτός αν --synthesize).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEM="$(cd "$HERE/../../memory" && pwd)"

REFLECTIVE="" ; VIEWS="" ; EDGES_OUT="" ; DRY=0 ; SYNTH=0 ; MAX_USD="" ; IGNORE_QH=0
QUIET_START="${RENEWAL_QUIET_START:-23}"   # owner-tunable
QUIET_END="${RENEWAL_QUIET_END:-8}"

while [ $# -gt 0 ]; do
  case "$1" in
    --reflective) REFLECTIVE="$2"; shift 2;;
    --views) VIEWS="$2"; shift 2;;
    --edges-out) EDGES_OUT="$2"; shift 2;;
    --dry-run) DRY=1; shift;;
    --synthesize) SYNTH=1; shift;;
    --max-usd) MAX_USD="$2"; shift 2;;
    --ignore-quiet-hours) IGNORE_QH=1; shift;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

[ -n "$REFLECTIVE" ] || { echo "need --reflective <dir>" >&2; exit 2; }
[ -n "$VIEWS" ] || { echo "need --views <dir>" >&2; exit 2; }
: "${EDGES_OUT:=$MEM/edges/edges.json}"

log(){ echo "[cycle] $*"; }

# --- Quiet hours gate (μην ενοχλείς) ---
hour=$(date +%-H)
if [ "$IGNORE_QH" -eq 0 ]; then
  in_quiet=0
  if [ "$QUIET_START" -gt "$QUIET_END" ]; then
    { [ "$hour" -ge "$QUIET_START" ] || [ "$hour" -lt "$QUIET_END" ]; } && in_quiet=1
  else
    { [ "$hour" -ge "$QUIET_START" ] && [ "$hour" -lt "$QUIET_END" ]; } && in_quiet=1
  fi
  # Ο κύκλος ΘΕΛΕΙ να τρέχει σε ήσυχες ώρες· εδώ απλώς το σημειώνουμε.
  [ "$in_quiet" -eq 1 ] && log "quiet-hours window ($QUIET_START-$QUIET_END) — output held, no pings"
fi

log "① ΜΑΖΕΨΕ — reflective dir: $REFLECTIVE"
[ -d "$REFLECTIVE" ] || { echo "reflective dir missing" >&2; exit 1; }

log "② ΚΑΛΩΔΙΩΣΕ — edge_extract (zero-LLM)"
if [ "$DRY" -eq 1 ]; then
  python3 "$MEM/edge_extract.py" "$REFLECTIVE" --json >/dev/null
  log "   dry-run: edges computed, not written"
else
  python3 "$MEM/edge_extract.py" "$REFLECTIVE" --out "$EDGES_OUT" >/dev/null
  log "   edges → $EDGES_OUT"
fi

log "③ ΑΝΙΧΝΕΥΣΕ — stale_check (zero-LLM)"
STALE_JSON=$(python3 "$MEM/stale_check.py" --views "$VIEWS" --reflective "$REFLECTIVE" --json)
stale_count=$(echo "$STALE_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin)['stale_count'])")
log "   stale views: $stale_count"

log "④ ΞΑΝΑΧΤΙΣΕ"
if [ "$SYNTH" -eq 1 ]; then
  log "   --synthesize ON: θα καλούσε φθηνό μοντέλο με Iron Law (cap=${MAX_USD:-unset})"
  log "   ⛔ όριο: view = pointer-με-freshness, ΠΟΤΕ truth (δες CYCLE.md)"
  # (Η πραγματική κλήση μοντέλου είναι owner-enabled hook· εδώ placeholder.)
else
  log "   flag-only (default, zero-LLM): $stale_count stale views χρειάζονται ανθρώπινη ματιά"
fi

log "⑤ ΜΟΤΙΒΟ — patterns (≥N εμφανίσεις → patterns/)  [skeleton]"
log "⑥ ΚΛΑΔΕΨΕ — forget orphans/τελειωμένες διάρκειες  [skeleton, δεν κλαδεύει ζωντανά]"

log "ΟΚ — κύκλος ολοκληρώθηκε (dry=$DRY synth=$SYNTH)"
