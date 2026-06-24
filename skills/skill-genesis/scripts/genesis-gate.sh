#!/usr/bin/env bash
# genesis-gate.sh — το proof harness. Δοθέντος ενός ΠΑΡΑΓΟΜΕΝΟΥ skill, κρίνει αν
# πληροί τα κριτήρια που το council απέδειξε ότι μετράνε. HARD gate: exit 1 αν σπάσει.
#
# Το council σύγκλινε: το failure είναι στο activation/routing boundary. Άρα το gate
# δεν ελέγχει «καλό body» — ελέγχει αν το skill θα ΕΝΕΡΓΟΠΟΙΗΘΕΙ σωστά μέσα στο σύστημα.
#
# Checks (HARD):
#   1. Έγκυρο frontmatter (name + description)
#   2. description = routing contract: έχει Use-when ΚΑΙ Don't-use-when σήμα
#   3. risk-tier δηλωμένο (HIGH-blast-radius / VOLATILE / STABLE)
#   4. namespace collision < 0.5 (μέσω namespace-scan)
#   5. body < 5000 bytes (progressive disclosure — βάθος σε references/)
#   6. αν VOLATILE: υπάρχει staleness/regenerate σήμα
#
# Usage: genesis-gate.sh <path-to-skill-dir-or-SKILL.md>
set -euo pipefail

TARGET="${1:-}"
[ -z "$TARGET" ] && { echo "usage: genesis-gate.sh <skill-dir|SKILL.md>" >&2; exit 2; }

# Resolve σε SKILL.md
if [ -d "$TARGET" ]; then SKILL="$TARGET/SKILL.md"; else SKILL="$TARGET"; fi
[ -f "$SKILL" ] || { echo "✗ δεν βρέθηκε: $SKILL" >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILS=0
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAILS=$((FAILS+1)); }

echo "── genesis-gate: $SKILL"

# Όλη η λογική σε python — passing path ως arg (όχι stdin, scar 24/6).
python3 - "$SKILL" <<'PYEOF'
import sys, re
skill = sys.argv[1]
txt = open(skill, encoding="utf-8").read()

m = re.search(r"^---\s*$(.*?)^---\s*$", txt, re.M | re.S)
fm = m.group(1) if m else ""
body = txt[m.end():] if m else txt

checks = []

# 1. frontmatter name + description
name = re.search(r'name:\s*"?([^"\n]+)"?', fm)
desc_m = re.search(r'description:\s*"?(.+?)"?\s*$', fm, re.S | re.M)
desc = (desc_m.group(1) if desc_m else "")
checks.append(("frontmatter: name + description", bool(name) and len(desc) > 20))

# 2. routing contract: Use-when ΚΑΙ Don't-use-when σήμα (στο description Ή body)
hay = (desc + " " + body).lower()
use_when = bool(re.search(r"use when|triggers?:|όταν|use for|activates? on|χρησιμοποίησ|trigger", hay))
dont = bool(re.search(r"don'?t use|do not use|μην|όχι για|not for|avoid when|ΜΗΝ", hay))
checks.append(("routing contract: Use-when σήμα", use_when))
checks.append(("routing contract: Don't-use-when σήμα", dont))

# 3. risk-tier δηλωμένο
tier_m = re.search(r"\b(HIGH[- ]?blast|VOLATILE|STABLE)\b", txt, re.I)
checks.append(("risk-tier δηλωμένο (HIGH-blast/VOLATILE/STABLE)", bool(tier_m)))

# 5. body < 5000 bytes (progressive disclosure)
bbytes = len(body.encode("utf-8"))
checks.append((f"body < 5000 bytes (είναι {bbytes})", bbytes < 5000))

# 6. αν VOLATILE → staleness signal
is_volatile = bool(tier_m and tier_m.group(1).upper().startswith("VOLATILE"))
if is_volatile:
    stale = bool(re.search(r"stale|regenerate|refresh|frontier|re-?run|ξαναγ|φρεσκ|volatil", hay))
    checks.append(("VOLATILE → staleness/regenerate σήμα", stale))

failed = 0
for label, ok in checks:
    print(f"  {'✓' if ok else '✗'} {label}")
    if not ok: failed += 1

# γράψε το proposed description σε temp για το namespace check (bash το διαβάζει)
open("/tmp/.gg_desc.txt", "w", encoding="utf-8").write(desc)
sys.exit(1 if failed else 0)
PYEOF
PYRC=$?
[ $PYRC -ne 0 ] && FAILS=$((FAILS+PYRC))

# 4. namespace collision (το proposed description vs ΟΛΑ τα άλλα skills)
if [ -f /tmp/.gg_desc.txt ]; then
  DESC="$(cat /tmp/.gg_desc.txt)"
  SELF_NAME="$(basename "$(cd "$(dirname "$SKILL")" && pwd)")"
  # Namespace = το parent skills/ του ίδιου + τα global (portable: δουλεύει και στον σπόρο).
  SELF_PARENT="$(cd "$(dirname "$SKILL")/.." && pwd)"
  SCAN_DIRS="$SELF_PARENT $HOME/.openclaw/workspace/skills $HOME/.openclaw/skills"
  # Εξαίρεση ΚΑΤΑ NAME (όχι path): ported copies έχουν ίδιο name = ο ίδιος εαυτός.
  COLL=$(SKILL_DIRS="$SCAN_DIRS" \
    bash "$SCRIPT_DIR/namespace-scan.sh" --proposed "$DESC" --json 2>/dev/null \
    | python3 -c "
import sys,json
d=json.load(sys.stdin)
self='$SELF_NAME'
others=[s for s in d['skills'] if s['name']!=self]
worst=max((s['overlap'] for s in others), default=0)
print(worst)
" 2>/dev/null || echo "1.0")
  if python3 -c "import sys; sys.exit(0 if float('$COLL')<0.5 else 1)" 2>/dev/null; then
    pass "namespace collision < 0.5 (max $COLL)"
  else
    fail "namespace collision ≥ 0.5 (max $COLL) — συγκρούεται με υπάρχον skill"
  fi
  rm -f /tmp/.gg_desc.txt
fi

# 7. scripts τρέχουν (bash -n σε κάθε .sh του skill) — αλλιώς skill με σπασμένο script περνά
SKILL_DIR_ABS="$(cd "$(dirname "$SKILL")" && pwd)"
if [ -d "$SKILL_DIR_ABS/scripts" ]; then
  _bad=0
  for sh in "$SKILL_DIR_ABS"/scripts/*.sh; do
    [ -f "$sh" ] || continue
    bash -n "$sh" 2>/dev/null || { _bad=$((_bad+1)); echo "      ↳ syntax error: $(basename "$sh")"; }
  done
  if [ $_bad -eq 0 ]; then pass "scripts syntax-valid (bash -n)"; else fail "$_bad script(s) με syntax error"; fi
fi

# 8. linked references υπάρχουν — αλλιώς dangling pointer
_miss=0
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  [ -f "$SKILL_DIR_ABS/$ref" ] || { _miss=$((_miss+1)); echo "      ↳ missing: $ref"; }
done < <(grep -oE '(references|assets|scripts)/[A-Za-z0-9._-]+' "$SKILL" | sort -u)
if [ $_miss -eq 0 ]; then pass "linked references/assets υπάρχουν"; else fail "$_miss linked path(s) λείπουν"; fi

echo "────────────────"
if [ $FAILS -eq 0 ]; then
  echo "🟢 GENESIS-GATE PASS — το skill ενεργοποιείται σωστά μέσα στο σύστημα"
  exit 0
else
  echo "🔴 GENESIS-GATE FAIL ($FAILS) — διόρθωσε πριν ship"
  exit 1
fi
