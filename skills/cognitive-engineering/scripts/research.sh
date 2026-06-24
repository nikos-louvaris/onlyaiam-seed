#!/usr/bin/env bash
# research.sh — Stage 1 layered research via Perplexity (OpenRouter → Sonar).
# 4 στρώσεις πηγών με ΕΝΑ τρόπο: official · arXiv · GitHub · Reddit-via-Perplexity.
# Κάθε query ζητά ρητά τα 6 μαζί: version/date · GitHub last-commit/stars ·
# real deployments · fps@res ή latency · hardware · license.
#
# Usage:
#   research.sh "<topic>" <out_dir> [--depth scan|deep]
#   research.sh --help
#
# --depth scan (default): perplexity/sonar-pro (γρήγορο landscape)
# --depth deep:           perplexity/sonar-reasoning-pro (multi-step, «άλλο επίπεδο»)
# ΣΗΜ (24/6 v2): το deep ΕΙΝΑΙ reasoning model — εντολή Νίκου «εκμεταλλεύσου το
# Perplexity πλήρως / άλλο επίπεδο» (PLAN §2). Τα αρχικά 3× empty/non-JSON ΔΕΝ
# έφταιγε το reasoning model — ήταν heredoc-stdin + max-time + citations bugs (όλα
# διορθωμένα). Live-verified: sonar-reasoning-pro → 3567 chars + 15 citations OK.
# Robust parse παρακάτω: αν content κενό, πέφτει στο reasoning field.
#
# Output: <out_dir>/findings/<layer>.md (citations always-on) → μετά χτίζεις
#         ledger.json χειροκίνητα/με κρίση, validate με `validate.py ledger`.
#
# Perplexity = δεδομένο για εμάς (OpenRouter key). Graceful degrade: αν λείπει
# key → γράφει skip-but-log marker, ΔΕΝ σκάει (για σπόρο/τρίτους).
set -euo pipefail

usage() {
  cat <<'EOF'
research.sh — Stage 1 layered research (Perplexity)

  research.sh "<topic>" <out_dir> [--depth scan|deep]

Στρώσεις (queries): official docs · arXiv/papers · GitHub repos · Reddit/practice.
Κάθε query ζητά: τρέχουσα έκδοση/date, GitHub last-commit/stars, real deployments,
fps@res ή latency, hardware (commodity/exotic), license.

--depth scan  → perplexity/sonar-pro (default, γρήγορο landscape)
--depth deep  → perplexity/sonar-reasoning-pro (multi-step «άλλο επίπεδο»)
EOF
}

case "${1:-}" in -h|--help) usage; exit 0 ;; esac

TOPIC="${1:-}"; OUTDIR="${2:-}"; shift 2 2>/dev/null || true
[ -n "$TOPIC" ]  || { echo "✗ λείπει \"<topic>\" (δες --help)" >&2; exit 1; }
[ -n "$OUTDIR" ] || { echo "✗ λείπει <out_dir> (δες --help)"  >&2; exit 1; }

DEPTH="scan"
while [ $# -gt 0 ]; do
  case "$1" in
    --depth) DEPTH="${2:-scan}"; shift 2 ;;
    *) shift ;;
  esac
done

# ΣΗΜΕΙΩΣΗ (24/6): για source-gathering το sonar-pro είναι το σωστό — γρήγορο,
# πλούσιο content + annotations. Τα sonar-reasoning* μοντέλα σπαταλούν tokens σε
# reasoning trace κι επιστρέφουν σχεδόν άδειο content (scar: 3× non-JSON/empty).
# deep → sonar-pro με μεγαλύτερο max_tokens (βάθος μέσω tokens, όχι μέσω reasoning).
case "$DEPTH" in
  scan) MODEL="perplexity/sonar-pro";           MAXTOK=3000 ;;
  deep) MODEL="perplexity/sonar-reasoning-pro"; MAXTOK=8000 ;;
  *) echo "✗ --depth πρέπει scan|deep" >&2; exit 1 ;;
esac

# Env loading (portable): CE_ENV override → seed standard → legacy. Δες setup.sh.
for _envf in "${CE_ENV:-}" "$HOME/.openclaw/credentials/.env"; do
  [ -n "$_envf" ] && [ -f "$_envf" ] && { . "$_envf" 2>/dev/null || true; break; }
done

mkdir -p "$OUTDIR/findings"

# graceful degrade αν λείπει key (σπόρος/τρίτοι)
if [ -z "${OPENROUTER_API_KEY:-}" ]; then
  echo "⚠ OPENROUTER_API_KEY λείπει → degraded mode (skip-but-log)" >&2
  echo "# DEGRADED — δεν υπάρχει Perplexity access. Research layer skipped." \
    > "$OUTDIR/findings/_DEGRADED.md"
  echo "Topic: $TOPIC" >> "$OUTDIR/findings/_DEGRADED.md"
  exit 0
fi

SIX="Για ΚΑΘΕ εργαλείο/paper/repo δώσε ΜΑΖΙ: (1) τρέχουσα έκδοση/ημερομηνία, (2) GitHub last-commit & stars (αν repo), (3) πραγματικά deployments, (4) fps@resolution ή latency, (5) hardware (commodity vs exotic), (6) license. Κάθε ισχυρισμός ΜΕ link/πηγή. Ό,τι δεν τεκμηριώνεται → πες 'UNVERIFIED', μην μαντεύεις."

# bash 3.2-safe (όχι associative array — ο σπόρος τρέχει σε macOS /bin/bash 3.2):
layer_query() {
  case "$1" in
    official) echo "Επίσημη τεκμηρίωση & canonical πηγές για: $TOPIC. $SIX" ;;
    arxiv)    echo "Επιστημονικά papers (site:arxiv.org OR ACL/NeurIPS) για: $TOPIC. Δώσε arXiv-id + ημερομηνία για κάθε paper. $SIX" ;;
    github)   echo "Τι υπάρχει ΗΔΗ χτισμένο στο GitHub (site:github.com) για: $TOPIC. Active repos, last-commit ~3 μήνες, archived ή όχι. $SIX" ;;
    reddit)   echo "Advanced practice & outlier thinking από Reddit (site:reddit.com r/LocalLLaMA, r/MachineLearning, r/PromptEngineering) για: $TOPIC. Τι δουλεύει στην πράξη που τα docs δεν λένε. $SIX" ;;
  esac
}

echo "── Research: «$TOPIC» · depth=$DEPTH ($MODEL) · 4 στρώσεις"
for layer in official arxiv github reddit; do
  Q="$(layer_query "$layer")"
  PAYLOAD=$(python3 -c "
import json,sys
print(json.dumps({'model':sys.argv[1],'messages':[{'role':'user','content':sys.argv[2]}],'max_tokens':int(sys.argv[3])}))
" "$MODEL" "$Q" "$MAXTOK")
  # Perplexity rate-limit-άρει γρήγορα διαδοχικά requests → έως 3 προσπάθειες με backoff (scar 24/6).
  R=""
  for attempt in 1 2 3; do
    R=$(curl -s "https://openrouter.ai/api/v1/chat/completions" \
      -H "Authorization: Bearer $OPENROUTER_API_KEY" \
      -H "Content-Type: application/json" \
      -H "HTTP-Referer: https://onlyaiam.com" \
      -d "$PAYLOAD" --max-time 240)
    # αν πήραμε ουσιαστικό JSON (όχι κενό/whitespace) → break
    [ "$(printf '%s' "$R" | tr -d '[:space:]' | head -c 1)" = "{" ] && break
    sleep $((attempt * 5))
  done
  # Το JSON περνά μέσω FILE, ΟΧΙ stdin — το heredoc (<<PYEOF) καταναλώνει το stdin
  # και το pipe χάνεται (scar 24/6: R γεμάτο αλλά raw='' στο python).
  _RESP="$OUTDIR/findings/.$layer.raw.json"
  printf '%s' "$R" > "$_RESP"
  python3 - "$layer" "$OUTDIR/findings/$layer.md" "$TOPIC" "$_RESP" <<'PYEOF'
import json,sys
layer=sys.argv[1]; out=sys.argv[2]; topic=sys.argv[3]; respf=sys.argv[4]
raw=open(respf,encoding="utf-8").read().strip()
# Perplexity/OpenRouter στέλνει leading keep-alive whitespace πριν το JSON — strip πρώτα.
try: d=json.loads(raw)
except Exception as e: d={"error":{"message":f"non-JSON ({e}); head={raw[:80]!r}"}}
if "error" in d:
    sys.stderr.write(f"ERR {layer}: {d['error']}\n"); sys.exit(0)
m=(d.get("choices") or [{}])[0].get("message",{})
msg=m.get("content") or ""
# reasoning models (deep) μερικές φορές βάζουν το σώμα στο reasoning field· fallback.
if not msg.strip(): msg=m.get("reasoning") or ""
# citations: νέο schema = message.annotations[].url_citation.url· fallback παλιό top-level
cites=[a.get("url_citation",{}).get("url") for a in (m.get("annotations") or []) if a.get("url_citation")]
if not cites: cites=d.get("citations") or []
with open(out,"w",encoding="utf-8") as f:
    f.write(f"# Research [{layer}] — {topic}\n\n{msg}\n")
    if cites:
        f.write("\n## Citations\n")
        for i,c in enumerate(cites,1): f.write(f"{i}. {c}\n")
print(f"✓ {layer} → {out}")
PYEOF
  rm -f "$_RESP"
  sleep 4   # ανάσα μεταξύ layers — αποφυγή rate-limit
done

echo "────────────────"
echo "findings → $OUTDIR/findings/  (επόμενο: χτίσε ledger.json, validate.py ledger)"
