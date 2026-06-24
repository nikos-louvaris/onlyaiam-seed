#!/usr/bin/env bash
# setup.sh — Το «σετάρισμα» του cognitive-engineering skill.
#
# Η ΟΛΗ διαδικασία (research→council→synthesis→brief→turn) είναι ΗΔΗ εδώ.
# Λείπει μόνο ΕΝΑ πράγμα: να την συνδέσεις με μοντέλα μέσω OpenRouter.
# Αυτό το script κάνει ακριβώς αυτό — και ΜΟΝΟ αυτό.
#
# Φιλοσοφία (όπως όλος ο σπόρος): VERIFY-ONLY. ΔΕΝ γράφει το key σε αρχείο.
# Το key ζει στο περιβάλλον σου (env var ή δικό σου .env). Εμείς απλώς
# επιβεβαιώνουμε ότι δουλεύει + διαλέγουμε roster + κάνουμε live δοκιμή.
#
# Usage:
#   setup.sh            # interactive: probe key, προτείνει roster, live test
#   setup.sh --check    # μόνο verify (CI-friendly, μηδέν prompts)
#   setup.sh --help
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROSTER_FILE="$SCRIPT_DIR/scripts/.ce-roster"

# Τα 4 «ιδανικά» — πραγματικά διαφορετικά βάρη (το νόημα του council).
# Heterogeneity = αντίδοτο στο echo chamber. Θες ≥3 ΔΙΑΦΟΡΕΤΙΚΟΥΣ vendors.
IDEAL=(
  "openai/gpt-5.4-pro"
  "google/gemini-2.5-pro"
  "anthropic/claude-opus-4.8"
  "deepseek/deepseek-r1"
)

usage() {
  cat <<'EOF'
setup.sh — σετάρισμα του cognitive-engineering skill (verify-only)

  setup.sh            interactive: probe OpenRouter, προτείνει roster, live test
  setup.sh --check    μόνο verify (μηδέν prompts, CI-friendly· exit 0/1)
  setup.sh --help

Τι κάνει:
  1. Βρίσκει το OPENROUTER_API_KEY (env ή CE_ENV ή standard .env paths).
  2. Χτυπά το OpenRouter /models και δείχνει ποια από τα 4 ιδανικά μοντέλα
     είναι διαθέσιμα σε ΣΕΝΑ.
  3. Προτείνει roster ≥3 διαφορετικών vendors → γράφει scripts/.ce-roster.
  4. Κάνει 1 live council-style call για να επιβεβαιώσει end-to-end.

Δεν γράφει ΠΟΤΕ το key σε αρχείο. Το key μένει στο δικό σου περιβάλλον.

Πώς δίνεις το key (διάλεξε ένα):
  export OPENROUTER_API_KEY=sk-or-...                  # στο shell σου
  echo 'OPENROUTER_API_KEY=sk-or-...' > ~/.openclaw/credentials/.env
  CE_ENV=/path/to/.env setup.sh   # custom path
EOF
}

MODE="interactive"
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --check)   MODE="check" ;;
  "")        ;;
  *) echo "✗ άγνωστο: $1 (δες --help)" >&2; exit 2 ;;
esac

# ── 1. Φόρτωσε key (ίδια σειρά με τα scripts) ────────────────────────────────
for _envf in "${CE_ENV:-}" "$HOME/.openclaw/credentials/.env"; do
  [ -n "$_envf" ] && [ -f "$_envf" ] && { . "$_envf" 2>/dev/null || true; break; }
done

if [ -z "${OPENROUTER_API_KEY:-}" ]; then
  echo "❌ OPENROUTER_API_KEY δεν βρέθηκε."
  echo ""
  echo "   Δώσε το key με έναν από τους τρόπους:"
  echo "     export OPENROUTER_API_KEY=sk-or-..."
  echo "     echo 'OPENROUTER_API_KEY=sk-or-...' > ~/.openclaw/credentials/.env"
  echo "     CE_ENV=/path/to/.env $0"
  echo ""
  echo "   Πάρε key: https://openrouter.ai/keys"
  exit 1
fi
echo "✅ OPENROUTER_API_KEY βρέθηκε."

# ── 2. Probe /models ─────────────────────────────────────────────────────────
echo "── Probe OpenRouter /models …"
MODELS_JSON=$(curl -s "https://openrouter.ai/api/v1/models" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" --max-time 30 2>/dev/null) || MODELS_JSON=""

if [ -z "$MODELS_JSON" ] || ! printf '%s' "$MODELS_JSON" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
  echo "❌ Το /models δεν απάντησε σωστά. Έλεγξε key/δίκτυο."
  exit 1
fi

AVAIL=$(printf '%s' "$MODELS_JSON" | python3 -c '
import json,sys
d=json.load(sys.stdin)
ids={m.get("id","") for m in d.get("data",[])}
for x in sys.argv[1:]:
    print(("OK" if x in ids else "NO")+"\t"+x)
' "${IDEAL[@]}")

echo ""
echo "   Διαθεσιμότητα ιδανικών μοντέλων (σε ΕΣΕΝΑ):"
OK_MODELS=()
while IFS=$'\t' read -r st mdl; do
  if [ "$st" = "OK" ]; then echo "     ✅ $mdl"; OK_MODELS+=("$mdl"); else echo "     ⬜ $mdl (μη διαθέσιμο)"; fi
done <<< "$AVAIL"

# ── 3. Πρότεινε/γράψε roster ─────────────────────────────────────────────────
echo ""
N_OK=${#OK_MODELS[@]}
if [ "$N_OK" -ge 3 ]; then
  echo "✅ $N_OK/4 ιδανικά διαθέσιμα — αρκετά για heterogeneity (≥3 vendors)."
  ROSTER="${OK_MODELS[*]}"
else
  echo "⚠ Μόνο $N_OK/4 ιδανικά διαθέσιμα. Το council θέλει ≥3 ΔΙΑΦΟΡΕΤΙΚΟΥΣ vendors."
  echo "   Πρόσθεσε χειροκίνητα μοντέλα στο: $ROSTER_FILE"
  ROSTER="${OK_MODELS[*]}"
fi

if [ "$MODE" = "check" ]; then
  [ "$N_OK" -ge 3 ] && { echo "✅ CHECK OK ($N_OK vendors)"; exit 0; } || { echo "❌ CHECK: <3 vendors"; exit 1; }
fi

# γράψε .ce-roster (config, ΟΧΙ secret)
{
  echo "# CE council roster — ένα model ανά γραμμή. # = σχόλιο."
  echo "# Γεννήθηκε από setup.sh $(date -u +%Y-%m-%dT%H:%MZ). Επεξεργάσιμο ελεύθερα."
  echo "# Κανόνας: ≥3 ΔΙΑΦΟΡΕΤΙΚΟΙ vendors (heterogeneity = το νόημα του council)."
  for m in $ROSTER; do echo "$m"; done
} > "$ROSTER_FILE"
echo "✅ Roster γράφτηκε: $ROSTER_FILE"

# ── 4. Live test (1 φθηνό call) ──────────────────────────────────────────────
echo ""
echo "── Live test (1 call στο πρώτο model του roster) …"
FIRST=$(printf '%s' "$ROSTER" | awk '{print $1}')
TEST=$(curl -s "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"messages":[{"role":"user","content":"Reply with exactly: CE_OK"}],"max_tokens":20}))' "$FIRST")" \
  --max-time 60 2>/dev/null) || TEST=""

OUT=$(printf '%s' "$TEST" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("PARSE_FAIL"); sys.exit()
if "error" in d: print("ERR:"+str(d["error"].get("message",""))); sys.exit()
print((d.get("choices") or [{}])[0].get("message",{}).get("content","").strip() or "EMPTY")
' 2>/dev/null)

if printf '%s' "$OUT" | grep -q "CE_OK"; then
  echo "✅ Live test OK ($FIRST απάντησε)."
  echo ""
  echo "🟢 ΕΤΟΙΜΟ. Τρέξε:  bash scripts/research.sh \"<topic>\" out/   (δες SKILL.md)"
  exit 0
else
  echo "⚠ Live test: '$OUT' (το key/roster ίσως χρειάζεται έλεγχο, αλλά το setup ολοκληρώθηκε)."
  exit 0
fi
