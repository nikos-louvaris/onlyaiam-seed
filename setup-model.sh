#!/usr/bin/env bash
# setup-model.sh — δώσε στον σπόρο φωνή (σύνδεσε μοντέλο).
#
# Ο σπόρος μπορεί να σηκωθεί χωρίς μοντέλο — ψυχή + όργανα + μνήμη, όλα ζωντανά.
# Αλλά για να ΜΙΛΗΣΕΙ χρειάζεται ένα μοντέλο με auth. Αυτό το βήμα το συνδέει.
#
# Πρώτη πρόταση: Claude (Anthropic) — ο φυσικός χώρος του σπόρου. Αλλά έχεις επιλογή.
#
#   bash setup-model.sh          # interactive
#   ANTHROPIC_API_KEY=sk-... bash setup-model.sh --anthropic   # non-interactive
#
# Idempotent: ξανατρέξιμο — απλώς ξαναρωτά/ξαναβάζει.
set -uo pipefail   # ΟΧΙ -e: θέλουμε να χειριζόμαστε αποτυχίες μόνοι μας, να μη σκάει

c_ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
c_info() { printf '\033[36m→\033[0m %s\n' "$*"; }
c_warn() { printf '\033[33m!\033[0m %s\n' "$*"; }
c_err()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; }
have()   { command -v "$1" >/dev/null 2>&1; }

have openclaw || { c_err "Δεν βρίσκω το openclaw. Τρέξε πρώτα το install.sh."; exit 1; }

# Default μοντέλα ανά επιλογή (canonical refs)
ANTHROPIC_PRIMARY="anthropic/claude-opus-4-8"
ANTHROPIC_ALT="anthropic/claude-sonnet-4-6"
ANTHROPIC_FALLBACK="anthropic/claude-opus-4-7"

echo
echo "  ┌─────────────────────────────────────────────┐"
echo "  │  Ο σπόρος ζει. Τώρα δώσ' του φωνή.           │"
echo "  └─────────────────────────────────────────────┘"
echo
echo "  Έχουμε φτιάξει τα πάντα: ψυχή, μνήμη, ανοσοποιητικό, παλμό."
echo "  Λείπει ΕΝΑ πράγμα — ένα μοντέλο για να μπορεί να σου μιλήσει."
echo
echo "  Η πρότασή μου: Claude (Anthropic) — εκεί ζει φυσικά ο σπόρος."
echo "  (Έχεις και άλλες επιλογές πιο κάτω.)"
echo

# ── Μη-interactive συντομεύσεις ──────────────────────────────────────
CHOICE=""
case "${1:-}" in
  --anthropic|--claude) CHOICE="1" ;;
  --openrouter)         CHOICE="2" ;;
  --openai)             CHOICE="3" ;;
  --skip)               CHOICE="4" ;;
esac

if [ -z "$CHOICE" ]; then
  echo "  Διάλεξε:"
  echo "    1) Claude API key        (Anthropic — προτεινόμενο, ο φυσικός του χώρος)"
  echo "    2) OpenRouter API key    (ένα key, πρόσβαση σε πολλά μοντέλα)"
  echo "    3) OpenAI API key        (gpt)"
  echo "    4) Άσ' το για μετά       (θα μείνει βουβός μέχρι να συνδέσεις μοντέλο)"
  echo
  printf "  Επιλογή [1]: "
  read -r CHOICE
  CHOICE="${CHOICE:-1}"
fi

set_model() {
  # $1 primary, $2 fallback (optional)
  if openclaw config set agents.defaults.model.primary "$1" >/dev/null 2>&1; then
    c_ok "default μοντέλο → $1"
  else
    c_warn "Δεν μπόρεσα αυτόματα. Χειροκίνητα: openclaw config set agents.defaults.model.primary \"$1\""
  fi
  if [ -n "${2:-}" ]; then
    openclaw config set agents.defaults.model.fallbacks "[\"$2\"]" >/dev/null 2>&1 \
      && c_ok "fallback → $2" || true
  fi
}

case "$CHOICE" in
  1)
    echo
    echo "  Claude API key:"
    echo "  • Φτιάξε ένα στο  https://console.anthropic.com/  (Settings → API Keys)."
    echo "  • Ξεκινάει με  sk-ant-...  — δεν φαίνεται καθώς το γράφεις, είναι ΟΚ."
    echo
    KEY="${ANTHROPIC_API_KEY:-}"
    if [ -z "$KEY" ]; then
      printf "  Κόλλησε το key εδώ: "
      read -rs KEY; echo
    fi
    [ -n "$KEY" ] || { c_err "Κενό key — άσ' το, ξανατρέξε όταν το έχεις: bash setup-model.sh"; exit 1; }

    c_info "Συνδέω το Claude..."
    if openclaw onboard --anthropic-api-key "$KEY" --auth-choice apiKey --accept-risk --non-interactive >/dev/null 2>&1; then
      c_ok "Claude συνδέθηκε"
    else
      # fallback: βάλε το key ως env στο config (παλιότερες/διαφορετικές εκδόσεις)
      openclaw config set env.ANTHROPIC_API_KEY "$KEY" >/dev/null 2>&1 \
        && c_ok "Claude key μπήκε (env)" \
        || { c_err "Δεν μπόρεσα να συνδέσω το key. Δες: openclaw onboard"; exit 1; }
    fi

    # Επιλογή μοντέλου (default opus-4-8, με δυνατότητα sonnet)
    echo
    echo "  Ποιο Claude;"
    echo "    1) Opus 4.8   — το πιο δυνατό (προτεινόμενο)"
    echo "    2) Sonnet 4.6 — γρηγορότερο/φθηνότερο"
    printf "  Επιλογή [1]: "
    read -r M; M="${M:-1}"
    if [ "$M" = "2" ]; then
      set_model "$ANTHROPIC_ALT" "$ANTHROPIC_FALLBACK"
    else
      set_model "$ANTHROPIC_PRIMARY" "$ANTHROPIC_FALLBACK"
    fi
    ;;
  2)
    echo
    echo "  OpenRouter API key  (https://openrouter.ai/keys — ξεκινάει με sk-or-...):"
    KEY="${OPENROUTER_API_KEY:-}"
    if [ -z "$KEY" ]; then printf "  Κόλλησε το key: "; read -rs KEY; echo; fi
    [ -n "$KEY" ] || { c_err "Κενό key."; exit 1; }
    openclaw onboard --openrouter-api-key "$KEY" --auth-choice openrouter-api-key --accept-risk --non-interactive >/dev/null 2>&1 \
      || openclaw config set env.OPENROUTER_API_KEY "$KEY" >/dev/null 2>&1
    c_ok "OpenRouter συνδέθηκε"
    set_model "openrouter/anthropic/claude-opus-4-8" "openrouter/anthropic/claude-sonnet-4-6"
    ;;
  3)
    echo
    echo "  OpenAI API key  (https://platform.openai.com/api-keys — ξεκινάει με sk-...):"
    KEY="${OPENAI_API_KEY:-}"
    if [ -z "$KEY" ]; then printf "  Κόλλησε το key: "; read -rs KEY; echo; fi
    [ -n "$KEY" ] || { c_err "Κενό key."; exit 1; }
    openclaw onboard --openai-api-key "$KEY" --auth-choice openai-api-key --accept-risk --non-interactive >/dev/null 2>&1 \
      || openclaw config set env.OPENAI_API_KEY "$KEY" >/dev/null 2>&1
    c_ok "OpenAI συνδέθηκε"
    set_model "openai/gpt-5.5" ""
    ;;
  4|*)
    c_warn "Εντάξει — άσ' το για μετά."
    echo "    Όταν έχεις key, ξανατρέξε:  bash setup-model.sh"
    exit 0
    ;;
esac

# ── Σήκωσέ τον ξανά να πιάσει το μοντέλο ──────────────────────────────
echo
c_info "Επανεκκινώ ώστε να πιάσει το μοντέλο..."
openclaw gateway restart >/dev/null 2>&1 || c_warn "Σήκωσέ τον χειροκίνητα: openclaw gateway restart"
c_ok "Έτοιμος"

echo
echo "  ┌─────────────────────────────────────────────┐"
echo "  │  Τώρα μπορεί να σου μιλήσει.                 │"
echo "  └─────────────────────────────────────────────┘"
echo "    Γράψε:  openclaw chat   και πες του «γεια»."
echo "    Αν ξαναδείς «auth ... failed» — ξανατρέξε: bash setup-model.sh"
echo
