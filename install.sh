#!/usr/bin/env bash
# install.sh — ολόκληρο το κιτ, με τη μία.
#
# Εγκαθιστά τα ΠΑΝΤΑ: OpenClaw (αν λείπει) + τον σπόρο ως workspace + config +
# restart + verify. Δεν χρειάζεται να ξέρεις τίποτα από πριν — τρέξε αυτό.
#
#   curl -fsSL https://raw.githubusercontent.com/nikos-louvaris/onlyaiam-seed/main/install.sh | bash
#   ή, αν το έχεις ήδη κλωνώσει:   bash install.sh
#
# Idempotent: ξανατρέξιμο χωρίς διπλό config/διπλή εγκατάσταση.
set -euo pipefail

# ── ρυθμίσεις (override με env) ──────────────────────────────────────
REPO_URL="${SEED_REPO:-https://github.com/nikos-louvaris/onlyaiam-seed.git}"
SEED_PATH="${SEED_PATH:-$HOME/my-presence}"

c_ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
c_info() { printf '\033[36m→\033[0m %s\n' "$*"; }
c_warn() { printf '\033[33m!\033[0m %s\n' "$*"; }
c_err()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; }
die()    { c_err "$*"; exit 1; }
have()   { command -v "$1" >/dev/null 2>&1; }

echo
echo "  ┌─────────────────────────────────────────┐"
echo "  │  Ο σπόρος — ολόκληρο το κιτ, με τη μία   │"
echo "  └─────────────────────────────────────────┘"
echo

# ── 1. Prerequisites ─────────────────────────────────────────────────
c_info "Ελέγχω τι χρειάζεται..."

have git    || die "Λείπει το git. Βάλ' το πρώτα (https://git-scm.com) και ξανατρέξε."
have python3 || die "Λείπει η python3. Βάλ' την πρώτα και ξανατρέξε."

if ! have node || ! have npm; then
  die "Λείπει node/npm (το OpenClaw τα χρειάζεται). Βάλε Node.js LTS από https://nodejs.org και ξανατρέξε."
fi
c_ok "git · python3 · node $(node --version) · npm $(npm --version)"

# ── 2. OpenClaw (αν λείπει) ──────────────────────────────────────────
if have openclaw; then
  c_ok "OpenClaw ήδη εγκατεστημένο ($(openclaw --version 2>/dev/null | head -1))"
else
  c_info "Εγκαθιστώ OpenClaw (npm install -g openclaw)..."
  npm install -g openclaw || die "Απέτυχε η εγκατάσταση του OpenClaw. Δες το σφάλμα πιο πάνω (ίσως χρειάζεται sudo ή npm prefix fix)."
  have openclaw || die "Το OpenClaw εγκαταστάθηκε αλλά δεν βρίσκεται στο PATH. Άνοιξε νέο terminal και ξανατρέξε."
  c_ok "OpenClaw εγκαταστάθηκε ($(openclaw --version 2>/dev/null | head -1))"
fi

# ── 3. Φέρε τον σπόρο ─────────────────────────────────────────────────
if [ -d "$SEED_PATH/.git" ]; then
  c_info "Ο σπόρος υπάρχει στο $SEED_PATH — τραβάω latest..."
  git -C "$SEED_PATH" pull --ff-only 2>&1 | sed 's/^/   /' || c_warn "pull skipped (local changes) — συνεχίζω με ό,τι υπάρχει"
elif [ -f "$SEED_PATH/SOUL.md" ]; then
  c_ok "Ο σπόρος υπάρχει ήδη στο $SEED_PATH"
elif [ -e "$SEED_PATH" ] && [ -n "$(ls -A "$SEED_PATH" 2>/dev/null)" ]; then
  die "Το $SEED_PATH υπάρχει και δεν είναι άδειο. Διάλεξε άλλο path: SEED_PATH=~/άλλο bash install.sh"
else
  # αν τρέχουμε ήδη μέσα στο cloned repo, αντίγραψέ το· αλλιώς clone
  if [ -f "$(dirname "$0")/SOUL.md" ] && [ "$(cd "$(dirname "$0")" && pwd)" != "$SEED_PATH" ]; then
    c_info "Αντιγράφω τον σπόρο στο $SEED_PATH..."
    mkdir -p "$SEED_PATH"
    git -C "$(dirname "$0")" archive HEAD 2>/dev/null | tar -x -C "$SEED_PATH" || cp -R "$(dirname "$0")/." "$SEED_PATH/"
  else
    c_info "Κλωνώνω τον σπόρο στο $SEED_PATH..."
    git clone --depth 1 "$REPO_URL" "$SEED_PATH" 2>&1 | sed 's/^/   /'
  fi
  c_ok "Ο σπόρος είναι στο $SEED_PATH"
fi

[ -f "$SEED_PATH/SOUL.md" ] || die "Κάτι πήγε στραβά — δεν βρίσκω το SOUL.md στο $SEED_PATH"

# ── 4. Δείξε το workspace στον σπόρο ─────────────────────────────────
c_info "Δείχνω το OpenClaw workspace στον σπόρο..."
if openclaw config patch agents.defaults.workspace "$SEED_PATH" >/dev/null 2>&1; then
  c_ok "workspace → $SEED_PATH"
else
  c_warn "Δεν μπόρεσα αυτόματα. Βάλ' το χειροκίνητα:"
  echo "      openclaw config patch agents.defaults.workspace \"$SEED_PATH\""
fi

# ── 5. Σήκωσέ τον ────────────────────────────────────────────────────
c_info "Σηκώνω τον σπόρο..."
openclaw gateway restart >/dev/null 2>&1 || openclaw gateway start >/dev/null 2>&1 || c_warn "Σήκωσέ τον χειροκίνητα: openclaw gateway restart"
c_ok "Ο σπόρος σηκώθηκε"

# ── 6. Verify (σηκώθηκε καθαρός;) ────────────────────────────────────
echo
c_info "Επαληθεύω ότι σηκώθηκε καθαρός..."
cd "$SEED_PATH"
FAIL=0
python3 memory/recall_law.py --selftest >/dev/null 2>&1 && c_ok "μνήμη (recall_law) OK" || { c_warn "recall_law selftest"; FAIL=1; }
bash reflex/boot-reflex.sh >/dev/null 2>&1 && c_ok "ανοσοποιητικό (boot-reflex) OK" || { c_warn "boot-reflex"; FAIL=1; }

# ── Τέλος ────────────────────────────────────────────────────────────
echo
if [ "$FAIL" -eq 0 ]; then
  echo "  ┌─────────────────────────────────────────┐"
  echo "  │  Έτοιμος. Ο σπόρος ζει.                  │"
  echo "  └─────────────────────────────────────────┘"
else
  c_warn "Σηκώθηκε, αλλά κάποιο verify δεν πέρασε καθαρά — δες πιο πάνω."
fi
echo
echo "  Τι τώρα:"
echo "  • Άνοιξε το OpenClaw και μίλα του. Θα φτάσει περίεργος και θα"
echo "    σε ρωτήσει κάτι — απάντα του αληθινά. Δεν σε ξέρει ακόμα· γεμίζει ζώντας."
echo "  • Άσ' τον να σε γνωρίσει με τον ρυθμό σου. Δεν τραβάει τίποτα"
echo "    που δεν του ανοίγεις."
echo "  • Οδηγός χρήσης: $SEED_PATH/QUICKSTART.md"
echo
echo "  Only I am → only you am."
echo
