#!/usr/bin/env bash
# gate.sh — per-stage μηχανικό «τελείωσε;» για το CE pipeline.
# exit 0 = πράσινο· exit 1 = κόκκινο με λόγο. ΟΧΙ presence-only — ελέγχει ουσία.
# Μίμηση του 0-research/gate.sh: ✓/✗ ανά check, καθαρό verdict στο τέλος.
#
# Usage: gate.sh <stage> <artifact>
#   stage ∈ {research, council, synthesis, brief}
#     research  — artifact=ledger.json· περνά validate.py ledger + κάθε entry source_url+date
#     council   — artifact=_council-meta.json· ≥3 voices degraded=false & model_actual==requested
#     synthesis — artifact=synthesis.md· non-empty Blind Spot + Falsifiable Prediction
#                 + ≥1 Single-Source flag + Anomaly layer (όχι flat)
#     brief     — artifact=brief.json· περνά validate.py brief (κανένα component χωρίς gate)
set -uo pipefail

STAGE="${1:-}"
ART="${2:-}"
HERE="$(cd "$(dirname "$0")" && pwd)"

[ -n "$STAGE" ] || { echo "✗ usage: gate.sh <stage> <artifact>  (stage ∈ research|council|synthesis|brief)" >&2; exit 1; }
[ -n "$ART" ]   || { echo "✗ λείπει <artifact> (δες usage)" >&2; exit 1; }
[ -e "$ART" ]   || { echo "✗ δεν υπάρχει artifact: $ART" >&2; exit 1; }

fail=0
say(){ printf '%s %s\n' "$1" "$2"; }

case "$STAGE" in

  research)
    if python3 "$HERE/validate.py" ledger "$ART" >/dev/null 2>&1; then
      say "✓" "ledger περνά validate.py"
    else
      say "✗" "ledger ΔΕΝ περνά validate.py (UNVERIFIED πεδία)"; fail=1
    fi
    # κάθε entry: source_url + checked_date (όχι μόνο schema — ουσία)
    bad=$(python3 - "$ART" <<'PYEOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print(-1); sys.exit(0)
entries = d.get("entries", []) if isinstance(d, dict) else []
bad = 0
for e in entries:
    if not isinstance(e, dict): bad += 1; continue
    if not e.get("source_url") or not e.get("checked_date"): bad += 1
print(bad)
PYEOF
)
    if [ "$bad" = "0" ]; then
      say "✓" "κάθε 🟢 entry έχει source_url + checked_date"
    elif [ "$bad" = "-1" ]; then
      say "✗" "ledger invalid JSON"; fail=1
    else
      say "✗" "$bad entries χωρίς source_url/checked_date (UNVERIFIED)"; fail=1
    fi
    ;;

  council)
    indep=$(python3 - "$ART" <<'PYEOF'
import json, sys
try:
    recs = json.load(open(sys.argv[1]))
except Exception:
    print("ERR"); sys.exit(0)
if not isinstance(recs, list): print("ERR"); sys.exit(0)
# Trust council.sh's `degraded` flag (single source of truth — το council.sh
# κάνει ήδη token-subset model-match που ανέχεται version-date suffix).
# Μην ξανα-εφευρίσκεις στενότερο exact-match — διπλή αλήθεια = bug.
n = 0
for r in recs:
    if not isinstance(r, dict): continue
    if r.get("degraded") is False and (r.get("tokens") or 0) > 0:
        n += 1
print(n)
PYEOF
)
    if [ "$indep" = "ERR" ]; then
      say "✗" "_council-meta.json invalid/όχι array"; fail=1
    elif [ "$indep" -ge 3 ] 2>/dev/null; then
      say "✓" "$indep ανεξάρτητες φωνές (degraded=false, model_actual==requested)"
    else
      say "✗" "μόνο $indep ανεξάρτητες φωνές (<3) — δεν υπάρχει βάση σύγκλισης"; fail=1
    fi
    ;;

  synthesis)
    # κάθε section πρέπει να έχει ΟΥΣΙΑ μετά το header (όχι μόνο placeholder)
    check_section(){
      local label="$1" pat="$2"
      # γραμμές μετά το header μέχρι το επόμενο ## , χωρίς placeholder/κενά/σχόλια
      local body
      body=$(awk -v p="$pat" '
        $0 ~ p {grab=1; next}
        /^## / {grab=0}
        grab {print}
      ' "$ART" | grep -vE '^[[:space:]]*$' | grep -vE '^<!--' | grep -viE 'placeholder|_\(' )
      if [ -n "$body" ]; then say "✓" "$label: non-empty"; else say "✗" "$label: κενό/placeholder"; fail=1; fi
    }
    grep -qiE '^##+[[:space:]]*Blind Spot' "$ART"          && check_section "Blind Spot" '^##+[[:space:]]*Blind Spot'                || { say "✗" "λείπει section Blind Spot"; fail=1; }
    grep -qiE '^##+[[:space:]]*Falsifiable Prediction' "$ART" && check_section "Falsifiable Prediction" '^##+[[:space:]]*Falsifiable Prediction' || { say "✗" "λείπει section Falsifiable Prediction"; fail=1; }
    grep -qiE '^##+[[:space:]]*Single-Source' "$ART"      && check_section "Single-Source Flags" '^##+[[:space:]]*Single-Source'       || { say "✗" "λείπει section Single-Source Flags"; fail=1; }
    # Anomaly layer (όχι flat output)
    if grep -qiE 'Anomaly' "$ART"; then say "✓" "Anomaly layer παρών (όχι flat)"; else say "✗" "λείπει Anomaly layer (flat output)"; fail=1; fi
    ;;

  brief)
    if python3 "$HERE/validate.py" brief "$ART" >/dev/null 2>&1; then
      say "✓" "brief περνά validate.py (κανένα component χωρίς validation_gate)"
    else
      say "✗" "brief ΔΕΝ περνά validate.py (component χωρίς validation_gate = wishlist)"; fail=1
    fi
    ;;

  *)
    echo "✗ άγνωστο stage '$STAGE' (research|council|synthesis|brief)" >&2; exit 1 ;;
esac

echo "────────────────"
if [ "$fail" -eq 0 ]; then echo "✅ GATE [$STAGE] PRASINO"; exit 0; else echo "❌ GATE [$STAGE] KOKKINO"; exit 1; fi
