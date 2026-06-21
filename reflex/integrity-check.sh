#!/bin/bash
# integrity-check.sh — identity/bootstrap files must match HEAD (or be staged).
# Truth is the committed blob; drift is an unstaged diff (never a hand-written
# checksum file, which decays).
set -u; cd "$(dirname "$0")/.." || exit 2
FILES=( IDENTITY.md SOUL.md FIELD.md MEMORY.md )   # the seed's own identity files
git rev-parse --git-dir >/dev/null 2>&1 || { echo "ALERT: not a git repo"; exit 2; }
ALERT=0
for f in "${FILES[@]}"; do
  [[ -r "$f" ]] || { echo "  $f: MISSING"; ALERT=1; continue; }
  cur=$(git hash-object "$f"); head=$(git ls-tree HEAD -- "$f" | awk '{print $3}')
  [[ "$cur" == "$head" ]] && continue
  staged=$(git ls-files -s -- "$f" | awk '{print $2}')
  [[ "$staged" == "$cur" ]] || { echo "  $f: DRIFT (working tree ≠ HEAD, not staged)"; ALERT=1; }
done
[ $ALERT -eq 0 ] && { echo "OK integrity"; exit 0; }
echo "  → git diff <file> (review) / git add && commit (accept)"; exit 1
