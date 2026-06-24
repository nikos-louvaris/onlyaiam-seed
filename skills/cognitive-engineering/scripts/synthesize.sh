#!/usr/bin/env bash
# synthesize.sh — Oz synthesis protocol: claims-matrix → oracle → stability.
# ΟΧΙ summary· μετατόπιση. Διαβάζει τις φωνές ενός Council και βγάζει layered
# σύνθεση με ρητά: Convergence (3+), Divergence, Blind Spot, Falsifiable
# Prediction, Single-Source Flags, Anomaly layer.
#
# Usage: synthesize.sh <voices_dir> <out_file> [--oracle]
#        synthesize.sh --help
#
# Default (χωρίς --oracle): παράγει template/σκελετό — ΜΗΔΕΝ κόστος (dry-run safe).
# Με --oracle: ΕΝΑ OpenRouter call (Opus, high) που γεμίζει τα sections
#              adversarially (claims-matrix από τις πραγματικές φωνές).
set -euo pipefail

usage() {
  cat <<'EOF'
synthesize.sh — Oz synthesis protocol (claims-matrix → oracle → stability)

Usage:
  synthesize.sh <voices_dir> <out_file> [--oracle]
  synthesize.sh --help

Args:
  voices_dir   φάκελος με voices/*.md (output του council.sh — δίνεις είτε το
               out_dir είτε το out_dir/voices)
  out_file     το synthesis markdown
  --oracle     τρέξε τον adversarial synthesizer (Opus, high) — ΚΟΣΤΙΖΕΙ.
               χωρίς αυτό: template μόνο, μηδέν κόστος.

Env (μόνο με --oracle):
  OPENROUTER_API_KEY   από CE_ENV ή ~/.openclaw/credentials/.env
  ORACLE_MODEL         default anthropic/claude-opus-4.8
  MAXTOK               default 12000
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

VOICES_DIR="${1:-}"; OUT="${2:-}"; ORACLE="${3:-}"
[ -n "$VOICES_DIR" ] || { echo "✗ λείπει <voices_dir> (δες --help)" >&2; exit 1; }
[ -n "$OUT" ]        || { echo "✗ λείπει <out_file> (δες --help)"  >&2; exit 1; }
[ -d "$VOICES_DIR" ] || { echo "✗ δεν υπάρχει dir: $VOICES_DIR"    >&2; exit 1; }

# δέξου είτε out_dir είτε out_dir/voices
if [ -d "$VOICES_DIR/voices" ]; then
  VDIR="$VOICES_DIR/voices"
else
  VDIR="$VOICES_DIR"
fi

shopt -s nullglob
VOICE_FILES=("$VDIR"/*.md)
shopt -u nullglob
[ "${#VOICE_FILES[@]}" -gt 0 ] || { echo "✗ καμία *.md φωνή στο $VDIR" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"

if [ "$ORACLE" = "--oracle" ]; then
  # ── ORACLE MODE: ένα adversarial Opus call ────────────────────────────────
  # shellcheck disable=SC1090
  # Env loading (portable): CE_ENV override → seed standard → legacy.
  for _envf in "${CE_ENV:-}" "$HOME/.openclaw/credentials/.env"; do
    [ -n "$_envf" ] && [ -f "$_envf" ] && { . "$_envf" 2>/dev/null || true; break; }
  done
  : "${OPENROUTER_API_KEY:?OPENROUTER_API_KEY δεν βρέθηκε (--oracle χρειάζεται key) — τρέξε setup.sh}"
  ORACLE_MODEL="${ORACLE_MODEL:-anthropic/claude-opus-4.8}"
  MAXTOK="${MAXTOK:-12000}"

  CORPUS=""
  for vf in "${VOICE_FILES[@]}"; do
    CORPUS+="
===== ΦΩΝΗ: $(basename "$vf" .md) =====
$(cat "$vf")
"
  done

  PROMPT="Your job is NOT to summarize. You are the adversarial synthesizer of a Council. Below are independent voices, each reading the same corpus through a different pattern. Identify, with surgical precision:

1. STRONGEST CONVERGENT FINDING — the claim where 3+ voices hit the same signal from different roads. Quote which voices. Convergence from different patterns MEANS something; convergence from the same pattern is echo — distinguish.
2. MOST DIAGNOSTIC DIVERGENCE — not any disagreement, the one whose resolution would most change the architecture.
3. HIGHEST-VALUE BLIND SPOT — what NO voice saw but the corpus implies. This is the point of synthesis.
4. SINGLE BEST ARCHITECTURE — one concrete design, not a menu.
5. CLEANEST FALSIFIABLE PREDICTION — a measurable claim that could be proven wrong.
6. SINGLE-SOURCE FLAGS — every claim asserted by exactly ONE voice (unverified, keep alive, do not promote to convergent).

Output EXACTLY these sections as markdown headers:
## Claims Matrix
(table: claim | voices-agreeing | layer)
## Convergence (3+ voices)
## Divergence (diagnostic)
## Blind Spot
## Falsifiable Prediction
## Single-Source Flags
## Layered Output
(Verified / Probable / Speculative / Anomaly — NOT flat. Anomaly = a signal that fits no voice's pattern.)

=== COUNCIL VOICES ===
$CORPUS"

  PAYLOAD=$(MODEL="$ORACLE_MODEL" MAXTOK="$MAXTOK" python3 -c "
import json, os, sys
print(json.dumps({
  'model': os.environ['MODEL'],
  'messages': [{'role':'user','content': sys.argv[1]}],
  'max_tokens': int(os.environ['MAXTOK']),
  'temperature': 0.7,
}))
" "$PROMPT")

  RESULT=$(curl -s "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -H "HTTP-Referer: https://onlyaiam.com" \
    -d "$PAYLOAD" --max-time 400)

  REQ="$ORACLE_MODEL" OUT="$OUT" python3 - "$RESULT" <<'PYEOF'
import json, os, sys
raw = sys.argv[1]; req = os.environ["REQ"]; out = os.environ["OUT"]
d = json.loads(raw) if raw.strip() else {"error": {"message": "empty"}}
if "error" in d:
    sys.stderr.write("ERR oracle: " + json.dumps(d["error"], ensure_ascii=False) + "\n"); sys.exit(2)
ch = (d.get("choices") or [{}])[0]
msg = (ch.get("message") or {}).get("content") or ""
fr = ch.get("finish_reason", "?"); usage = d.get("usage", {})
actual = d.get("model", "")
if not msg.strip():
    sys.stderr.write(f"EMPTY oracle: finish_reason={fr}\n"); sys.exit(3)
deg = req.split(":")[0] != actual.split(":")[0]
hdr = f"# Council Synthesis — Oz protocol (oracle: {actual})\n"
if deg: hdr += f"> ⚠ [DEGRADED: got {actual}, wanted {req}]\n"
hdr += f"_tokens={usage.get('total_tokens','?')} · finish_reason={fr}_\n\n"
open(out, "w", encoding="utf-8").write(hdr + msg)
print(f"OK oracle -> {out} ({usage.get('total_tokens','?')} tok)")
PYEOF
  echo "✓ synthesis (oracle) → $OUT"
  exit 0
fi

# ── TEMPLATE MODE (default, ΜΗΔΕΝ κόστος) ────────────────────────────────────
VOICE_LIST=""
for vf in "${VOICE_FILES[@]}"; do
  VOICE_LIST+="- \`$(basename "$vf" .md)\`"$'\n'
done

cat > "$OUT" <<EOF
# Council Synthesis — Oz protocol (TEMPLATE)

> Σκελετός — δεν τρέχει oracle. Γέμισέ τον με το χέρι ή ξανατρέξε με \`--oracle\`.
> ΑΡΧΗ: ΟΧΙ summary — μετατόπιση. Σύγκλιση από ΔΙΑΦΟΡΕΤΙΚΑ patterns σημαίνει κάτι·
> από το ίδιο pattern είναι echo.

Φωνές που διαβάστηκαν (${#VOICE_FILES[@]}):
$VOICE_LIST

## Claims Matrix
<!-- table: claim | voices-agreeing | layer(verified/probable/speculative/anomaly) -->
| claim | voices | layer |
|-------|--------|-------|
| _(placeholder)_ | _(πόσες φωνές)_ | _(layer)_ |

## Convergence (3+ voices)
<!-- πού χτυπούν το ΙΔΙΟ σήμα ≥3 φωνές από διαφορετικούς δρόμους -->
_(placeholder)_

## Divergence (diagnostic)
<!-- η διαφωνία της οποίας η επίλυση αλλάζει την αρχιτεκτονική -->
_(placeholder)_

## Blind Spot
<!-- το highest-value σημείο που ΚΑΝΕΝΑΣ δεν είδε αλλά το corpus υπονοεί -->
_(placeholder — ΥΠΟΧΡΕΩΤΙΚΟ, μη το αφήσεις κενό στο gate)_

## Falsifiable Prediction
<!-- μετρήσιμη πρόβλεψη που μπορεί να διαψευστεί -->
_(placeholder — ΥΠΟΧΡΕΩΤΙΚΟ)_

## Single-Source Flags
<!-- κάθε claim από ΑΚΡΙΒΩΣ μία φωνή — unverified, μένει ζωντανό, ΔΕΝ promote -->
_(placeholder — ≥1)_

## Layered Output
<!-- ΟΧΙ flat -->
- **Verified:** _(placeholder)_
- **Probable:** _(placeholder)_
- **Speculative:** _(placeholder)_
- **Anomaly:** _(placeholder — σήμα που δεν ταιριάζει σε κανένα pattern)_
EOF

echo "✓ synthesis template → $OUT (χωρίς oracle· μηδέν κόστος)"
echo "  ξανατρέξε με --oracle για adversarial fill"
exit 0
