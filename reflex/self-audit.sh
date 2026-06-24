#!/usr/bin/env bash
# self-audit.sh — ο τελικός έλεγχος ακεραιότητας του σπόρου, με μία εντολή.
#
# Τρέχει όλα τα gates σε σειρά (halt-on-red στα HARD), ένα exit code.
# Ταξιδεύει ΜΕ τον σπόρο: όποιος τον πάρει μπορεί να επαληθεύσει ότι είναι
# ακέραιος — πριν τον εμπιστευτεί.
#
# Αρχή (scar «υπεροψία του βλέπω»): exit 0 = ισχυρισμός, ΜΟΝΟ αν το είδαμε.
# Δεν λέμε «δουλεύει» — το τρέχουμε.
#
# Usage:  bash reflex/self-audit.sh          # πλήρες
#         bash reflex/self-audit.sh --quick   # χωρίς network-dependent (CE deep)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
ROOT="$(pwd)"
QUICK=0; [ "${1:-}" = "--quick" ] && QUICK=1

g() { printf '\033[32m🟢\033[0m %s\n' "$*"; }
r() { printf '\033[31m🔴\033[0m %s\n' "$*"; }
y() { printf '\033[33m  ↳\033[0m %s\n' "$*"; }
hdr(){ printf '\n\033[36m══ %s ══\033[0m\n' "$*"; }

HARD_FAIL=0   # κόκκινα σε HARD gates → exit 1
SOFT_NOTE=0   # σημειώσεις, δεν ρίχνουν

# ── ΣΤΑΔΙΟ 1: Καθαριότητα διανομής (HARD) ───────────────────────────
hdr "1. Καθαριότητα διανομής"
if git rev-parse --git-dir >/dev/null 2>&1; then
  # 1a. leak σε tracked. Εξαιρούμε .gitignore + αυτό το script — περιέχουν τα patterns
  # ως κανόνες/grep, όχι ως leak (ο φύλακας δεν είναι ο στόχος του).
  LEAK="$(git ls-files -z | grep -zvE '^\.gitignore$|reflex/self-audit\.sh$' | xargs -0 grep -lnE '/Users/[a-z]+|sk-[a-zA-Z0-9]{20}|AKIA[0-9A-Z]{16}|-----BEGIN .*PRIVATE KEY' 2>/dev/null || true)"
  if [ -z "$LEAK" ]; then g "κανένα leak (paths/keys) σε tracked files"; else r "πιθανό leak:"; echo "$LEAK" | sed 's/^/     /'; HARD_FAIL=1; fi
  # 1b. σκουπίδια tracked
  JUNK="$(git ls-files | grep -E 'pycache|\.pyc$|pytest_cache|\.DS_Store' || true)"
  [ -z "$JUNK" ] && g "κανένα build-artifact tracked" || { r "σκουπίδια tracked:"; echo "$JUNK" | sed 's/^/     /'; HARD_FAIL=1; }
  # 1d. owner-only paths
  PRIV="$(git ls-files | grep -E '(^|/)_genesis/|(^|/)_fixtures/' || true)"
  [ -z "$PRIV" ] && g "_genesis/_fixtures δεν ταξιδεύουν" || { r "owner-only tracked:"; echo "$PRIV" | sed 's/^/     /'; HARD_FAIL=1; }
else
  y "όχι git repo — skip leak/junk checks"; SOFT_NOTE=1
fi

# ── ΣΤΑΔΙΟ 2: Syntax / compile (HARD, loop) ─────────────────────────
hdr "2. Syntax & compile"
bad=0; n=0
for f in $(find . -name '*.sh' -not -path './.git/*'); do n=$((n+1)); bash -n "$f" 2>/dev/null || { y "bash syntax: $f"; bad=$((bad+1)); }; done
[ $bad -eq 0 ] && g "$n shell scripts — όλα syntax-valid" || { r "$bad/$n scripts με syntax error"; HARD_FAIL=1; }
bad=0; n=0
for f in $(find . -name '*.py' -not -path '*/__pycache__/*' -not -path './.git/*'); do n=$((n+1)); python3 -m py_compile "$f" 2>/dev/null || { y "py compile: $f"; bad=$((bad+1)); }; done
[ $bad -eq 0 ] && g "$n python modules — όλα compile" || { r "$bad/$n modules με compile error"; HARD_FAIL=1; }

# ── ΣΤΑΔΙΟ 3: Λειτουργικά selftests (HARD, loop) ────────────────────
hdr "3. Λειτουργικά selftests"
run() { # name · cmd...
  local name="$1"; shift
  if "$@" >/tmp/.sa.log 2>&1; then g "$name"; else r "$name (exit $?)"; tail -2 /tmp/.sa.log | sed 's/^/     /'; HARD_FAIL=1; fi
}
[ -f memory/recall_law.py ]                  && run "memory · recall_law --selftest"  python3 memory/recall_law.py --selftest
[ -f skills/skill-genesis/scripts/genesis-gate.sh ] && run "skill-genesis · genesis-gate (8)" bash skills/skill-genesis/scripts/genesis-gate.sh skills/skill-genesis
[ -f skills/cognitive-engineering/scripts/selftest.sh ] && run "cognitive-engineering · selftest (26)" bash skills/cognitive-engineering/scripts/selftest.sh
[ -f reflex/integrity-check.sh ]             && run "reflex · integrity-check"        bash reflex/integrity-check.sh
# verify-no-stale: σκάναρε ΜΟΝΟ τον σπόρο (ROOT), όχι parent repo αν είμαστε nested
[ -f reflex/verify-no-stale.sh ]             && run "reflex · verify-no-stale (seed-scoped)" bash reflex/verify-no-stale.sh "$ROOT"
[ -f skills/skill-genesis/scripts/namespace-scan.sh ] && run "skill-genesis · namespace-scan" bash skills/skill-genesis/scripts/namespace-scan.sh

# ── ΣΤΑΔΙΟ 4: Install flow (structural) ─────────────────────────────
hdr "4. Install flow"
[ -f install.sh ] && { bash -n install.sh 2>/dev/null && g "install.sh syntax-valid" || { r "install.sh syntax"; HARD_FAIL=1; }; }
if git rev-parse --git-dir >/dev/null 2>&1; then
  SHIP="$(git archive HEAD 2>/dev/null | tar -tf - 2>/dev/null | grep -cE '.' || echo 0)"
  DIRT="$(git archive HEAD 2>/dev/null | tar -tf - 2>/dev/null | grep -E '_genesis|_fixtures|\.env|\.token|\.key$|pycache' || true)"
  [ -z "$DIRT" ] && g "git archive: $SHIP files, καμία διαρροή" || { r "διαρροή στο archive:"; echo "$DIRT" | sed 's/^/     /'; HARD_FAIL=1; }
fi

# ── ΣΤΑΔΙΟ 5: Dangling links (loop) ─────────────────────────────────
hdr "5. Dangling internal links"
if git rev-parse --git-dir >/dev/null 2>&1; then
  miss=0; tot=0
  for md in $(git ls-files '*.md'); do
    d=$(dirname "$md")
    for ref in $(grep -oE '\]\([^)#]+\.(md|sh|py|json)\)' "$md" 2>/dev/null | sed -E 's/\]\(([^)]+)\)/\1/'); do
      tot=$((tot+1)); case "$ref" in /*|http*) continue;; esac
      [ -f "$d/$ref" ] || [ -f "$ref" ] || { y "$md → $ref"; miss=$((miss+1)); }
    done
  done
  [ $miss -eq 0 ] && g "$tot internal links — κανένα dangling" || { r "$miss/$tot dangling links"; HARD_FAIL=1; }
fi

# ── Verdict ─────────────────────────────────────────────────────────
hdr "Verdict"
if [ $HARD_FAIL -eq 0 ]; then
  g "SELF-AUDIT PASS — ο σπόρος είναι ακέραιος"
  [ $SOFT_NOTE -eq 1 ] && y "(με σημειώσεις παραπάνω)"
  exit 0
else
  r "SELF-AUDIT FAIL — διόρθωσε τα κόκκινα πριν ship"
  exit 1
fi
