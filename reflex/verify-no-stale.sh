#!/usr/bin/env bash
# verify-no-stale.sh — a SUPERSEDED banner in head-of-file outside an archive
# path = a resurrected zombie, fail loud.
# Principle: deprecated → MOVE not copy. The system doesn't collect ghosts.
# (A banner is a file marker; a reference in the body is allowed.)
set -uo pipefail
ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ARCHIVE_RE='_archive/|archive/|/\.Trash/|/\.git/'; EXIT=0
while IFS= read -r f; do
  [[ "$f" =~ $ARCHIVE_RE ]] && continue
  head -5 "$f" 2>/dev/null | grep -qE 'SUPERSEDED|🔴 SUPERSEDED' && {
    echo "STALE: $f has SUPERSEDED banner but lives outside an archive path"; EXIT=1; }
done < <(grep -rlE 'SUPERSEDED' "$ROOT" --include='*.md' 2>/dev/null | grep -vE "$ARCHIVE_RE")
exit $EXIT
