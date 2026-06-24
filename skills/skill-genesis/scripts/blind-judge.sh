#!/usr/bin/env bash
# blind-judge.sh — ο τυφλός κριτής της Κίνησης 5. Structural separation:
# ένα ΔΙΑΦΟΡΕΤΙΚΟ μοντέλο, που ΔΕΝ βλέπει την πρόθεση/τη γέννα, κρίνει αν το skill
# κάνει αυτά που υπόσχεται — μόνο από το artifact. (Αρχή: hook/references/blind-judge.md.)
#
# Γιατί όχι in-context: όταν ο builder κρίνει στο ίδιο νήμα, διαρρέει η πρόθεση →
# rationalization engine. Ο κριτής λαμβάνει ΜΟΝΟ το SKILL.md, χωρίς να ξέρει τι ήθελες.
#
# Usage: blind-judge.sh <skill-dir|SKILL.md> [--model <openrouter-model>]
# Default model: openai/gpt-5.4-pro (διαφορετικός από τον τυπικό Anthropic builder).
# Χρειάζεται OPENROUTER_API_KEY (env ή ~/.openclaw/credentials/.env). Degrade: αν λείπει,
# τυπώνει το prompt για χειροκίνητο κριτή (exit 3).
set -euo pipefail

TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "usage: blind-judge.sh <skill-dir|SKILL.md> [--model M]" >&2; exit 2; }
shift || true
MODEL="openai/gpt-5.4-pro"
[ "${1:-}" = "--model" ] && { MODEL="${2:-$MODEL}"; }

if [ -d "$TARGET" ]; then SKILL="$TARGET/SKILL.md"; else SKILL="$TARGET"; fi
[ -f "$SKILL" ] || { echo "✗ δεν βρέθηκε: $SKILL" >&2; exit 2; }

# Key
KEY="${OPENROUTER_API_KEY:-}"
if [ -z "$KEY" ] && [ -f "$HOME/.openclaw/credentials/.env" ]; then
  KEY="$( . "$HOME/.openclaw/credentials/.env" 2>/dev/null; echo "${OPENROUTER_API_KEY:-}")"
fi

JUDGE_PROMPT='Είσαι αυστηρός κριτής agent skills (Anthropic SKILL.md format). Σου δίνω ΕΝΑ skill (συνοδεύεται από references/, scripts/, assets/template). ΔΕΝ ξέρεις πώς φτιάχτηκε. Κρίνε ΜΟΝΟ το artifact, σύντομα.
1. SPECIALIST ή GENERIC; (κάνει κάτι συγκεκριμένο vs γενικότητες που ξέρει ήδη το base model)
2. Routing contract: μπορείς να πεις ΠΟΤΕ ενεργοποιείται και ΠΟΤΕ ΟΧΙ, μόνο από το description; (ναι/όχι + 1 γραμμή)
3. Έχει σαφές output contract (τι παράγει); (ναι/όχι)
4. Top-2 αδυναμίες.
5. Τελευταία γραμμή ΑΚΡΙΒΩΣ: {"verdict":"SHIP" ή "DONT-SHIP","type":"SPECIALIST" ή "GENERIC","routing_clear":true ή false}'

SKILL_CONTENT="$(cat "$SKILL")"

if [ -z "$KEY" ]; then
  echo "⚠ OPENROUTER_API_KEY λείπει — degrade σε χειροκίνητο κριτή." >&2
  echo "── PROMPT ΓΙΑ ΤΥΦΛΟ ΚΡΙΤΗ (δώσε σε ξεχωριστό μοντέλο/session) ──"
  printf '%s\n\n=== SKILL ===\n%s\n' "$JUDGE_PROMPT" "$SKILL_CONTENT"
  exit 3
fi

PAYLOAD=$(python3 -c "
import json,sys
print(json.dumps({'model':sys.argv[1],'messages':[{'role':'user','content':sys.argv[2]+chr(10)+chr(10)+'=== SKILL ==='+chr(10)+sys.argv[3]}],'max_tokens':6000}))
" "$MODEL" "$JUDGE_PROMPT" "$SKILL_CONTENT")
_TMP="$(mktemp)"; trap 'rm -f "$_TMP"' EXIT
printf '%s' "$PAYLOAD" > "$_TMP"

echo "── blind-judge: $SKILL (κριτής: $MODEL, held-out) ──"
RESP=$(curl -s "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d @"$_TMP" --max-time 220)

echo "$RESP" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
except Exception as e:
    print('✗ parse error:', e); sys.exit(4)
if 'choices' not in d:
    print('✗ no choices:', json.dumps(d)[:400]); sys.exit(4)
m=d['choices'][0]['message']
c=(m.get('content') or '').strip()
if not c:
    print('✗ άδειο content (finish='+str(d['choices'][0].get('finish_reason'))+') — δοκίμασε άλλο model'); sys.exit(4)
print(c)
import re
mm=re.search(r'\{[^{}]*verdict[^{}]*\}', c)
if mm:
    try:
        v=json.loads(mm.group(0))
        print()
        print('VERDICT:', v.get('verdict'), '| type:', v.get('type'), '| routing_clear:', v.get('routing_clear'))
        sys.exit(0 if v.get('verdict')=='SHIP' else 1)
    except Exception:
        pass
sys.exit(0)
"
