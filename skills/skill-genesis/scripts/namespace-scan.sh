#!/usr/bin/env bash
# namespace-scan.sh — διαβάζει ΟΛΑ τα υπάρχοντα skills, βγάζει το dispatch table,
# και (προαιρετικά) flag-άρει overlap με ένα προτεινόμενο νέο description.
#
# Γιατί: το council σύγκλινε ότι το failure είναι στο activation/routing boundary.
# Πριν γεννήσεις skill, ΠΡΕΠΕΙ να ξέρεις τι ενεργοποιείται ήδη — αλλιώς namespace collision.
# (CE decision tree: «υπάρχει ήδη; → βρες το. Όχι; → μην ξαναχτίσεις.»)
#
# Usage:
#   namespace-scan.sh                          # λίστα όλων των skills (name + description)
#   namespace-scan.sh --proposed "desc text"   # + overlap score έναντι κάθε υπάρχοντος
#   namespace-scan.sh --json                    # machine-readable
set -euo pipefail

PROPOSED=""
JSON=0
while [ $# -gt 0 ]; do
  case "$1" in
    --proposed) PROPOSED="${2:-}"; shift 2 ;;
    --json) JSON=1; shift ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "✗ άγνωστο arg: $1" >&2; exit 1 ;;
  esac
done

# Skill dirs: workspace-local + user-global + NATIVE global (όλο το namespace).
# Το council: το failure είναι namespace-blindness. Αν αγνοήσεις τα native skills,
# το collision check είναι false-green (self-application 24/6 το έπιασε: 14 vs 71 skills).
# Portable (σπόρος): SKILL_DIRS override παρακάμπτει το auto-detect.
_native_skills_dir() {
  local r b real cand
  r="$(npm root -g 2>/dev/null)" && [ -d "$r/openclaw/skills" ] && { echo "$r/openclaw/skills"; return; }
  b="$(command -v openclaw 2>/dev/null)" || true
  if [ -n "$b" ]; then
    real="$(cd "$(dirname "$b")" && pwd)"
    for cand in "$real/../lib/node_modules/openclaw/skills" "$real/../../lib/node_modules/openclaw/skills"; do
      [ -d "$cand" ] && { (cd "$cand" && pwd); return; }
    done
  fi
  [ -d "/opt/homebrew/lib/node_modules/openclaw/skills" ] && { echo "/opt/homebrew/lib/node_modules/openclaw/skills"; return; }
  return 0
}
DEFAULT_DIRS="$HOME/.openclaw/workspace/skills $HOME/.openclaw/skills"
_NATIVE="$(_native_skills_dir)"
[ -n "$_NATIVE" ] && DEFAULT_DIRS="$DEFAULT_DIRS $_NATIVE"
DIRS="${SKILL_DIRS:-$DEFAULT_DIRS}"

# Μάζεψε όλα τα SKILL.md
FILES=""
for d in $DIRS; do
  [ -d "$d" ] || continue
  for f in "$d"/*/SKILL.md; do
    [ -f "$f" ] && FILES="$FILES $f"
  done
done

if [ -z "$FILES" ]; then
  echo "⚠ δεν βρέθηκαν skills σε: $DIRS" >&2
  exit 0
fi

# Python κάνει το parse (frontmatter name/description) + overlap.
# Τα FILES περνούν μέσω temp file (ΟΧΙ stdin) — το heredoc <<PYEOF καταναλώνει το stdin
# κι ο pipe χάνεται (scar 24/6, ίδιο με research.sh).
_FLIST="$(mktemp)"
trap 'rm -f "$_FLIST"' EXIT
printf '%s\n' $FILES > "$_FLIST"
python3 - "$PROPOSED" "$JSON" "$_FLIST" <<'PYEOF'
import sys, re, json
proposed = sys.argv[1].lower()
as_json = sys.argv[2] == "1"
files = [l.strip() for l in open(sys.argv[3], encoding="utf-8") if l.strip()]

STOP = set("the a an of to for and or with in on as is be when not use this that your you it από και για με σε το η ο τα οι ένα μια όταν πώς αν δεν".split())

def tokens(s):
    s = s.lower()
    return set(w for w in re.findall(r"[a-zα-ω0-9]+", s) if w not in STOP and len(w) > 2)

def parse(f):
    try:
        txt = open(f, encoding="utf-8").read()
    except Exception:
        return None
    m = re.search(r"^---\s*$(.*?)^---\s*$", txt, re.M | re.S)
    fm = m.group(1) if m else txt[:1500]
    name = re.search(r'name:\s*"?([^"\n]+)"?', fm)
    d = _extract_desc(fm)
    d = re.sub(r'\s+', ' ', d)[:400]
    return {"file": f, "name": name.group(1).strip() if name else "?", "desc": d}

def _extract_desc(fm):
    # YAML block scalar: `description: |` ή `>` → μάζεψε τις indented γραμμές που ακολουθούν.
    # (scar self-application 24/6: το single-line regex έπιανε μόνο '|' → loopcraft/re-member αόρατα)
    mb = re.search(r'^description:\s*[|>][-+]?\s*$', fm, re.M)
    if mb:
        lines = fm[mb.end():].split("\n")
        out = []
        for ln in lines[1:] if lines and lines[0] == "" else lines:
            if ln.strip() == "":
                out.append(""); continue
            if re.match(r'^\s+', ln):       # indented → μέρος του block
                out.append(ln.strip())
            elif re.match(r'^\S', ln):      # νέο top-level key → τέλος block
                break
        return " ".join(x for x in out if x).strip()
    # Inline: description: "..." ή description: ...
    mi = re.search(r'description:\s*"?(.+?)"?\s*$', fm, re.S | re.M)
    return mi.group(1).strip() if mi else ""

skills = [p for f in files if (p := parse(f))]
ptoks = tokens(proposed) if proposed else set()

results = []
for s in skills:
    overlap = 0.0
    if ptoks:
        stoks = tokens(s["desc"]) | tokens(s["name"])
        inter = ptoks & stoks
        overlap = round(len(inter) / max(1, len(ptoks)), 2)
    s["overlap"] = overlap
    results.append(s)

if proposed:
    results.sort(key=lambda x: -x["overlap"])

if as_json:
    print(json.dumps({"count": len(results), "proposed": proposed, "skills": results}, ensure_ascii=False, indent=2))
else:
    print(f"── Namespace: {len(results)} skills" + (f" · overlap vs proposed" if proposed else ""))
    for s in results:
        tag = ""
        if proposed:
            if s["overlap"] >= 0.5: tag = f"  🔴 COLLISION {s['overlap']}"
            elif s["overlap"] >= 0.3: tag = f"  🟡 near {s['overlap']}"
            else: tag = f"  ⚪ {s['overlap']}"
        print(f"  {s['name']:24s}{tag}")
        print(f"      {s['desc'][:90]}")
    if proposed:
        worst = max((s["overlap"] for s in results), default=0)
        print()
        if worst >= 0.5:
            print(f"⚠ HIGH collision (max {worst}) — το proposed description συγκρούεται. Διαφοροποίησε ή ορχήστρωσε το υπάρχον.")
        elif worst >= 0.3:
            print(f"~ moderate overlap (max {worst}) — σφίξε το Use-when/Don't-use-when.")
        else:
            print(f"✓ clear namespace (max {worst}) — το proposed δεν συγκρούεται.")
PYEOF
