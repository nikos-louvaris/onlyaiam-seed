#!/usr/bin/env bash
# selftest.sh — μηχανικό «όλα δουλεύουν;» για το CE skill, ΧΩΡΙΣ κόστος.
# Κωδικοποιεί το audit της 24/6: gates+validators ΚΑΙ περνούν το καλό ΚΑΙ
# κόβουν το κακό (gate που δεν κόβει ποτέ = theater), schemas valid, και —
# κρίσιμα — ο σπόρος είναι byte-identical με το live skill (το drift-scar 24/6).
#
# ΔΕΝ τρέχει live council/research (κοστίζει + αργεί). Για live: --live.
#
# Usage:
#   selftest.sh            # δωρεάν: validators + gates + schemas + seed-parity
#   selftest.sh --live     # + ΕΝΑ μικρό live research probe (κοστίζει λίγο)
#   selftest.sh --help
#
# exit 0 = όλα πράσινα· exit 1 = κάτι έσπασε (με λόγο).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$(cd "$HERE/.." && pwd)"
S="$HERE"
FIX="$SKILL/assets/fixtures"
SCHEMA="$SKILL/assets/schemas"

case "${1:-}" in -h|--help)
  sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

PASS=0; FAIL=0
ok(){   printf '  ✅ %s\n' "$1"; PASS=$((PASS+1)); }
bad(){  printf '  ❌ %s\n' "$1"; FAIL=$((FAIL+1)); }
hdr(){  printf '\n── %s\n' "$1"; }

# expect_pass <label> <cmd...>   — η εντολή ΠΡΕΠΕΙ exit 0
expect_pass(){ local l="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$l"; else bad "$l (έπρεπε PASS)"; fi; }
# expect_fail <label> <cmd...>   — η εντολή ΠΡΕΠΕΙ exit ≠0 (gate πρέπει να κόβει)
expect_fail(){ local l="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$l (GATE THEATER — δεν έκοψε το κακό)"; else ok "$l"; fi; }

echo "════════ CE skill selftest ════════"

# ── 1. validate.py: good→PASS, bad→FAIL ─────────────────────────────────────
hdr "validate.py (good περνά · bad κόβεται)"
for k in ledger brief rubric; do
  expect_pass "$k-good περνά"  python3 "$S/validate.py" "$k" "$FIX/$k-good.json"
  expect_fail "$k-bad κόβεται" python3 "$S/validate.py" "$k" "$FIX/$k-bad.json"
done

# ── 2. gate.sh: good→PASS, bad→FAIL (research/brief/synthesis/council) ───────
hdr "gate.sh research+brief (fixtures)"
expect_pass "research ledger-good"  bash "$S/gate.sh" research "$FIX/ledger-good.json"
expect_fail "research ledger-bad"   bash "$S/gate.sh" research "$FIX/ledger-bad.json"
expect_pass "brief brief-good"      bash "$S/gate.sh" brief    "$FIX/brief-good.json"
expect_fail "brief brief-bad"       bash "$S/gate.sh" brief    "$FIX/brief-bad.json"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

hdr "gate.sh council (synthetic meta · date-suffix tolerance)"
cat > "$TMP/meta-good.json" <<'EOF'
[{"voice":"a","model_requested":"openai/gpt-5.4-pro","model_actual":"openai/gpt-5.4-pro-20260305","degraded":false,"tokens":1200,"latency":4.1,"finish_reason":"stop"},
 {"voice":"b","model_requested":"google/gemini-2.5-pro","model_actual":"google/gemini-2.5-pro","degraded":false,"tokens":1500,"latency":5.0,"finish_reason":"stop"},
 {"voice":"c","model_requested":"anthropic/claude-opus-4.8","model_actual":"anthropic/claude-4.8-opus-20260528","degraded":false,"tokens":1800,"latency":6.2,"finish_reason":"stop"}]
EOF
cat > "$TMP/meta-bad.json" <<'EOF'
[{"voice":"a","model_requested":"openai/gpt-5.4-pro","model_actual":"openai/gpt-5.4-pro","degraded":false,"tokens":1200,"latency":4.1,"finish_reason":"stop"},
 {"voice":"b","model_requested":"google/gemini-2.5-pro","model_actual":"google/gemini-2.5-pro","degraded":false,"tokens":1500,"latency":5.0,"finish_reason":"stop"},
 {"voice":"c","model_requested":"anthropic/claude-opus-4.8","model_actual":"openai/gpt-4o","degraded":true,"tokens":0,"latency":1.2,"finish_reason":"error"}]
EOF
expect_pass "council 3-indep (date-suffix OK)" bash "$S/gate.sh" council "$TMP/meta-good.json"
expect_fail "council 2-indep κόβεται"          bash "$S/gate.sh" council "$TMP/meta-bad.json"

hdr "gate.sh synthesis (placeholder κόβεται · γεμάτο περνά)"
mkdir -p "$TMP/voices"; printf '# v\nx\n' > "$TMP/voices/a.md"
bash "$S/synthesize.sh" "$TMP" "$TMP/tpl.md" >/dev/null 2>&1
expect_fail "synthesis template (placeholder) κόβεται" bash "$S/gate.sh" synthesis "$TMP/tpl.md"
cat > "$TMP/synth-full.md" <<'EOF'
# Synthesis
## Claims Matrix
| claim | voices | layer |
|---|---|---|
| X | 3 | verified |
## Convergence (3+ voices)
Three voices hit the latency wall.
## Divergence (diagnostic)
GPU-bound vs IO-bound — changes the design.
## Blind Spot
License forbids commercial deployment.
## Falsifiable Prediction
At 4K throughput drops below 12fps.
## Single-Source Flags
Only Beta claims retraction — unverified.
## Layered Output
- Verified: latency
- Probable: GPU bottleneck
- Speculative: ASIC
- Anomaly: unreproducible 10x
EOF
expect_pass "synthesis γεμάτο περνά" bash "$S/gate.sh" synthesis "$TMP/synth-full.md"

# ── 3. schemas: valid Draft-07 ──────────────────────────────────────────────
hdr "schemas valid JSON"
for sc in "$SCHEMA"/*.json; do
  expect_pass "$(basename "$sc") valid JSON" python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$sc"
done

# ── 4. doc/code consistency (το anti-pattern 24/6: docs λένε άλλα, code άλλα) ─
hdr "doc/code consistency"
# research.sh: το --depth deep ΠΡΕΠΕΙ να τρέχει ΔΙΑΦΟΡΕΤΙΚΟ μοντέλο από το scan
# (εντολή Νίκου «άλλο επίπεδο» — αν deep==scan, το deep είναι ψευδεπίγραφο). PLAN §2.
scan_m=$(grep -oE 'scan\) +MODEL="[^"]+"' "$S/research.sh" | head -1 | sed 's/.*MODEL=//;s/"//g')
deep_m=$(grep -oE 'deep\) +MODEL="[^"]+"' "$S/research.sh" | head -1 | sed 's/.*MODEL=//;s/"//g')
if [ -n "$scan_m" ] && [ -n "$deep_m" ] && [ "$scan_m" != "$deep_m" ]; then
  ok "deep ($deep_m) ≠ scan ($scan_m) — «άλλο επίπεδο» ζωντανό"
else
  bad "deep==scan ($deep_m) — το «άλλο επίπεδο» χάθηκε (intent-drift)"
fi
# επίσης: deep πρέπει reasoning model + robust reasoning-field fallback στο parse
if grep -q 'reasoning' "$S/research.sh"; then ok "research.sh έχει reasoning-field fallback"; else bad "research.sh χωρίς reasoning-field fallback (deep θα βγάζει κενό)"; fi
# SKILL.md αναφέρει όλα τα scripts που υπάρχουν
for sname in gate.sh council.sh synthesize.sh validate.py research.sh; do
  [ -f "$S/$sname" ] || bad "λείπει script $sname"
done
ok "όλα τα scripts παρόντα"

# ── 5. seed parity (ΤΟ DRIFT-SCAR 24/6: live διορθώθηκε, σπόρος όχι) ─────────
hdr "seed↔live parity (drift-scar)"
SEED_GUESS=""
for cand in \
  "$SKILL/../../projects/onlyaiam-seed/seed/skills/cognitive-engineering/scripts" \
  "$HOME/.openclaw/workspace/projects/onlyaiam-seed/seed/skills/cognitive-engineering/scripts"; do
  [ -d "$cand" ] && { SEED_GUESS="$cand"; break; }
done
if [ -z "$SEED_GUESS" ]; then
  echo "  ⚠ σπόρος δεν βρέθηκε σε αυτό το περιβάλλον — skip parity (OK για τρίτους)"
else
  for sname in research.sh council.sh synthesize.sh gate.sh validate.py; do
    if diff -q "$S/$sname" "$SEED_GUESS/$sname" >/dev/null 2>&1; then
      ok "seed $sname identical"
    else
      bad "seed $sname DIFFERS από live (drift! sync τώρα)"
    fi
  done
  # SKILL.md parity επίσης
  if diff -q "$SKILL/SKILL.md" "$SEED_GUESS/../SKILL.md" >/dev/null 2>&1; then
    ok "seed SKILL.md identical"
  else bad "seed SKILL.md DIFFERS"; fi
fi

# ── 6. optional live probe ──────────────────────────────────────────────────
if [ "${1:-}" = "--live" ]; then
  hdr "LIVE research probe (κοστίζει — 1 topic, scan)"
  LT="$TMP/live"; 
  if bash "$S/research.sh" "DuckDB embedded analytics 2026" "$LT" --depth scan >/dev/null 2>&1; then
    n=$(ls "$LT/findings/"*.md 2>/dev/null | grep -vc DEGRADED || echo 0)
    [ "$n" -ge 1 ] && ok "research live: $n findings παρήχθησαν" || bad "research live: 0 findings"
  else
    bad "research live probe απέτυχε"
  fi
fi

# ── verdict ─────────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════"
echo "PASS=$PASS · FAIL=$FAIL"
if [ "$FAIL" -eq 0 ]; then echo "✅ CE SELFTEST PRASINO"; exit 0
else echo "❌ CE SELFTEST KOKKINO ($FAIL)"; exit 1; fi
