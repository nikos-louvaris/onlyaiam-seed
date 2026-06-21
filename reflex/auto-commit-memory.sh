#!/bin/bash
# auto-commit-memory.sh — memory is version-controlled by default, on cadence.
cd "${WORKSPACE:-$HOME/.openclaw/workspace}" || exit 0
for p in memory/ MEMORY.md IDENTITY.md SOUL.md; do   # the seed's own memory/identity paths
  [ -e "$p" ] && git add -A "$p" 2>/dev/null
done
git diff --cached --quiet 2>/dev/null || \
  git commit -m "auto: memory cadence $(date -u +%Y-%m-%dT%H:%MZ)" >/dev/null 2>&1
