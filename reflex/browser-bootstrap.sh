#!/bin/bash
# browser-bootstrap.sh — φέρε τον browser-rail στη latest μορφή (ή δες τι λείπει)
#
# Ο σπόρος ΔΕΝ κουβαλάει browser tool — ο browser είναι η τελευταία λύση, και
# όταν χρειαστεί, μπαίνει ΜΟΝΟ μέσα από ένα portal-στυλ CLI (ένας browser, ένας
# τρόπος· ποτέ raw `open`/CDP/browser-tool). Αυτό το script είναι το ΣΧΗΜΑ: ελέγχει
# αν ο rail υπάρχει, σε ποια μορφή, και πώς έρχεται στη latest — χωρίς να υποθέτει
# ότι ξέρει το δικό σου setup.
#
# Χρήση:
#   bash reflex/browser-bootstrap.sh          # έλεγξε presence + health + freshness
#   bash reflex/browser-bootstrap.sh --update  # φέρε στη latest (αν είναι git-based)
#
# Συμβάσεις (override με env):
#   PORTAL_BIN   — το CLI binary (default: portal στο PATH)
#   PORTAL_SRC   — ο φάκελος/repo όπου ζει ο κώδικας του rail (για --update)
set -uo pipefail

PORTAL_BIN="${PORTAL_BIN:-portal}"
PORTAL_SRC="${PORTAL_SRC:-}"
MODE="${1:-check}"

say()  { printf '%s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ── 1. Υπάρχει ο rail; ───────────────────────────────────────────────
if ! have "$PORTAL_BIN"; then
  say "⚪ browser-rail: ΔΕΝ είναι wired ακόμα."
  say ""
  say "Ο σπόρος ξεκινά χωρίς browser — by design (ο browser = τελευταία λύση)."
  say "Όταν τον χρειαστείς, ο κανόνας είναι: ΕΝΑΣ browser, ΕΝΑΣ τρόπος —"
  say "ένα portal-στυλ CLI με καθαρά verbs (open/login/verify/explore/status),"
  say "ποτέ raw \`open\`/CDP/browser-tool. Το όριο: σωστό port ≠ σωστή πόρτα."
  say ""
  say "Για να τον wire-άρεις:"
  say "  1. Βάλε το CLI σου στο PATH (ή όρισε PORTAL_BIN=/path/to/cli)."
  say "  2. (προαιρ.) όρισε PORTAL_SRC=<repo> για να τραβάς latest με --update."
  say "  3. Ξανατρέξε αυτό το script — θα ελέγξει health + freshness."
  exit 2
fi

RESOLVED="$(command -v "$PORTAL_BIN")"
say "✓ browser-rail παρών: $RESOLVED"

# ── 2. Health (ζει ο rail;) ──────────────────────────────────────────
if "$PORTAL_BIN" status >/dev/null 2>&1; then
  say "✓ health: ο rail απαντά (\`$PORTAL_BIN status\` OK)"
else
  say "⚠ health: ο rail υπάρχει αλλά \`status\` δεν απάντησε καθαρά — δες τα logs του."
fi

# ── 3. Freshness — είναι στη latest μορφή; ───────────────────────────
# Αν ο κώδικας ζει σε git repo, σύγκρινε local vs remote HEAD.
detect_src() {
  [ -n "$PORTAL_SRC" ] && { echo "$PORTAL_SRC"; return; }
  # μάντεψε: ο φάκελος του resolved binary, αν είναι μέσα σε git repo
  local d; d="$(cd "$(dirname "$RESOLVED")" && pwd)"
  git -C "$d" rev-parse --show-toplevel 2>/dev/null
}
SRC="$(detect_src)"

if [ -z "$SRC" ] || ! git -C "$SRC" rev-parse >/dev/null 2>&1; then
  say "⚪ freshness: δεν βρέθηκε git source (όρισε PORTAL_SRC=<repo> για auto-update)."
  say "   Ο rail δουλεύει· απλώς δεν μπορώ να ελέγξω/τραβήξω latest μόνος."
  exit 0
fi

LOCAL="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"
say "  source: $SRC @ $LOCAL"

if [ "$MODE" = "--update" ]; then
  say "→ τραβάω latest..."
  if git -C "$SRC" pull --ff-only 2>&1 | sed 's/^/  /'; then
    NEW="$(git -C "$SRC" rev-parse --short HEAD)"
    [ "$NEW" = "$LOCAL" ] && say "✓ ήδη στη latest ($NEW)" || say "✓ ενημερώθηκε: $LOCAL → $NEW"
  else
    say "⚠ pull απέτυχε (local changes; non-ff;) — λύσ' το χειροκίνητα, δεν πατάω από πάνω."
    exit 1
  fi
else
  git -C "$SRC" fetch --quiet 2>/dev/null || true
  REMOTE="$(git -C "$SRC" rev-parse --short '@{u}' 2>/dev/null || echo "$LOCAL")"
  if [ "$REMOTE" = "$LOCAL" ]; then
    say "✓ freshness: στη latest μορφή ($LOCAL)"
  else
    say "⚠ freshness: υπάρχει νεότερη ($LOCAL → $REMOTE). Τρέξε: bash reflex/browser-bootstrap.sh --update"
  fi
fi
