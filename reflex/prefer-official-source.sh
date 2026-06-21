#!/usr/bin/env bash
# prefer-official-source.sh "<category-or-tool>"   (--force to override)
# The "Never MCP-by-default" rule, as a rail instead of discipline.
# (CONNECTIONS: CLI > API > browser. MCP only when no official CLI/API road exists.)
#
# Call BEFORE wiring a connection. It checks whether an official CLI/API road
# exists for the category and refuses a silent MCP default.
#
# exit 0 = no MCP concern, or official road confirmed — proceed.
# exit 1 = MCP-by-default smell — an official CLI/API road exists; use it first.
set -euo pipefail

SEED="${SEED_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MAP="$SEED/CONNECTIONS.md"

[[ "${1:-}" == "--force" ]] && { shift; echo "FORCE: official-source check skipped (documented exception)"; exit 0; }
Q="${1:?usage: prefer-official-source.sh [--force] \"<category-or-tool>\"}"

ql="$(printf '%s' "$Q" | tr '[:upper:]' '[:lower:]')"

# Is the request reaching for MCP at all?
if ! printf '%s' "$ql" | grep -qE 'mcp|model context protocol'; then
  echo "OK: no MCP in request — normal CLI>API>browser path applies."
  exit 0
fi

# It mentions MCP. Does an official road exist for this category in the map?
# Strip the MCP word, look up the remaining category against CONNECTIONS.
cat_term="$(printf '%s' "$ql" | sed -E 's/(mcp|model context protocol|server|tool|by-default|default)//g' | xargs || true)"

echo "⚠️  MCP requested for: '$Q'"
echo "    Rule (CONNECTIONS): never MCP-by-default. Official CLI/API road first."
echo

if [[ -n "$cat_term" && -f "$MAP" ]]; then
  HIT="$(grep -iE "^\| *\**${cat_term}|${cat_term}.*API|${cat_term}.*CLI" "$MAP" 2>/dev/null | head -3 || true)"
  if [[ -n "$HIT" ]]; then
    echo "    An official road exists in CONNECTIONS for '${cat_term}':"
    echo "$HIT" | sed 's/^/      /'
    echo
    echo "    → Use the official CLI/API. Re-run with --force ONLY if you've"
    echo "      confirmed there is genuinely no official CLI/API road (document it)."
    exit 1
  fi
fi

echo "    No matching official road found in the map for '${cat_term}'."
echo "    Confirm in current upstream docs that no official CLI/API exists."
echo "    If truly none → --force (documented exception). Otherwise add the road to CONNECTIONS."
exit 1
