#!/bin/bash
# wsearch.sh "query" [--raw] — web search via a provider, KEY NEVER HARDCODED.
# The key is sourced from an env file; nothing secret ever lives in this file,
# so it is safe to ship and safe to read.
ENV_FILE="${ENV_FILE:-$HOME/.openclaw/secrets.env}"
if [ -z "${SEARCH_API_KEY:-}" ] && [ -f "$ENV_FILE" ]; then
  SEARCH_API_KEY=$(grep -E '^SEARCH_API_KEY=' "$ENV_FILE" | head -1 | cut -d= -f2-)
fi
[ -z "${SEARCH_API_KEY:-}" ] && { echo "ERROR: SEARCH_API_KEY not set / not in $ENV_FILE" >&2; exit 1; }
PROVIDER_ENDPOINT="${PROVIDER_ENDPOINT:-https://openrouter.ai/api/v1/chat/completions}"
SEARCH_MODEL="${SEARCH_MODEL:-perplexity/sonar}"
QUERY="${1:?usage: wsearch.sh \"query\" [--raw]}"
curl -s "$PROVIDER_ENDPOINT" -H "Authorization: Bearer $SEARCH_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$SEARCH_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":$(printf '%s' "$QUERY" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read().strip()))')}]}" \
  --max-time 30
