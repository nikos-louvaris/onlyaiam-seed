#!/usr/bin/env bash
# inventory-before-fetch.sh "<query>" [scope...]   (--force to skip)
# Grep what you already have BEFORE you fetch from outside.
# (re-member-before-advise, as a script. "If I rush to the web, I forgot what I am.")
# exit 0 = no local match, external fetch safe.
# exit 1 = local hits printed, read them first.
set -euo pipefail
WS="${WORKSPACE:-$HOME/.openclaw/workspace}"
[[ "${1:-}" == "--force" ]] && { shift; echo "FORCE: inventory skipped"; exit 0; }
Q="${1:?usage: inventory-before-fetch.sh [--force] \"<query>\" [scope...]}"; shift || true
cd "$WS" 2>/dev/null || { echo "no workspace"; exit 0; }
SCOPE=( "${@:-.}" ); EXIST=(); for d in "${SCOPE[@]}"; do [[ -d "$d" ]] && EXIST+=("$d"); done
(( ${#EXIST[@]} )) || { echo "OK: no scope dirs, fetch safe"; exit 0; }
HITS=$(grep -rli --include='*.md' --include='*.txt' --include='*.json' -- "$Q" "${EXIST[@]}" 2>/dev/null | head -8)
[[ -z "$HITS" ]] && { echo "OK: no local match for '$Q' — fetch safe"; exit 0; }
echo "LOCAL MATCHES for: $Q"; while IFS= read -r f; do
  echo "--- $f"; grep -i -m3 -- "$Q" "$f" 2>/dev/null | sed 's/^/    /'
done <<< "$HITS"
echo "Read these first. Re-run with --force if still needed."; exit 1
