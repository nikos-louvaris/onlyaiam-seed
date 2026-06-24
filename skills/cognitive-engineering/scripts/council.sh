#!/usr/bin/env bash
# council.sh — N-voice multi-model Council runner (ΤΟ ΚΕΝΤΡΙΚΟ).
# Κάθε φωνή = ΕΝΑ OpenRouter call με ΡΗΤΟ model (μία κλήση/μοντέλο, όπως
# resonance-research.sh). Δομική heterogeneity = αντίδοτο στο echo chamber.
#
# ΚΡΙΣΙΜΟ (Πρόβλημα 2 — silent fallback): διαβάζουμε το d['model'] από το
# response και το συγκρίνουμε με το requested. Αν διαφέρει → η φωνή γράφεται
# [DEGRADED], μπαίνει στο _degraded.log, και ΔΕΝ μετράει ως ανεξάρτητη ψήφος.
#
# Usage: council.sh <corpus_file> <charter_file> <out_dir>
#        council.sh --help
#
# Roster: διαβάζεται από το charter (γραμμές «Μοντέλο: `model`» κάτω από κάθε
# `### N.` voice header). Αν το charter δεν δώσει ≥3 voices → hardcoded fallback.
set -euo pipefail

usage() {
  cat <<'EOF'
council.sh — N-voice multi-model Council runner

Usage:
  council.sh <corpus_file> <charter_file> <out_dir>
  council.sh --help

Args:
  corpus_file   το corpus που διαβάζει ΚΑΘΕ φωνή (π.χ. FINDINGS.md + PLAN.md)
  charter_file  το charter (voice sections + per-voice `Μοντέλο: `model``)
  out_dir       φάκελος εξόδου (δημιουργείται)

Output:
  <out_dir>/voices/<voice-slug>.md   μία φωνή/αρχείο (header: model req+actual,
                                      tokens, latency, finish_reason)
  <out_dir>/_council-meta.json       array: voice, model_requested, model_actual,
                                      degraded, tokens, latency
  <out_dir>/_degraded.log            όσες φωνές γύρισαν λάθος μοντέλο

Env:
  OPENROUTER_API_KEY   το OpenRouter key (υποχρεωτικό)
  CE_ENV               προαιρετικό path σε .env που ορίζει το key (δες setup.sh)
  CE_ROSTER            προαιρετικό: roster fallback (space-sep models) ή scripts/.ce-roster
  MAXTOK               max_tokens/φωνή (default 8000)
  TEMP                 temperature (default 0.8)

Roster fallback (αν το charter δεν δώσει ≥3):
  openai/gpt-5.4-pro google/gemini-2.5-pro anthropic/claude-opus-4.8 deepseek/deepseek-r1
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

CORPUS="${1:-}"; CHARTER="${2:-}"; OUTDIR="${3:-}"
[ -n "$CORPUS" ]  || { echo "✗ λείπει <corpus_file> (δες --help)"  >&2; exit 1; }
[ -n "$CHARTER" ] || { echo "✗ λείπει <charter_file> (δες --help)" >&2; exit 1; }
[ -n "$OUTDIR" ]  || { echo "✗ λείπει <out_dir> (δες --help)"      >&2; exit 1; }
[ -f "$CORPUS" ]  || { echo "✗ δεν υπάρχει corpus: $CORPUS"   >&2; exit 1; }
[ -f "$CHARTER" ] || { echo "✗ δεν υπάρχει charter: $CHARTER" >&2; exit 1; }

# Env loading (portable): CE_ENV override → seed standard → legacy. Δες setup.sh.
for _envf in "${CE_ENV:-}" "$HOME/.openclaw/credentials/.env"; do
  [ -n "$_envf" ] && [ -f "$_envf" ] && { . "$_envf" 2>/dev/null || true; break; }
done
: "${OPENROUTER_API_KEY:?OPENROUTER_API_KEY δεν βρέθηκε — τρέξε setup.sh ή όρισε CE_ENV=/path/to/.env}"

# Reasoning models (gpt-5.x-pro, deepseek-r1, gemini-2.5-pro, o-series) ξοδεύουν
# max_tokens σε hidden reasoning πριν το content → χαμηλό ceiling = EMPTY. Το
# default ανεβαίνει σε 16000 ώστε η default συνταγή να μην βγάζει
# ψεύτικο κόκκινο council (W1 auditor 24/6). Override με MAXTOK=N.
MAXTOK="${MAXTOK:-16000}"
TEMP="${TEMP:-0.8}"

mkdir -p "$OUTDIR/voices"
META_LINES="$OUTDIR/_meta-lines.ndjson"
DEGRADED_LOG="$OUTDIR/_degraded.log"
: > "$META_LINES"
: > "$DEGRADED_LOG"

# ── 1. Εξαγωγή voices από το charter ────────────────────────────────────────
# Κάθε voice: slug | name | model | section-body. Παραλείπει sections που
# μαρκάρονται ως ΣΥΝΘΕΤΗΣ (αυτό το κάνει το synthesize.sh, όχι το council).
VOICES_TSV="$OUTDIR/_voices.tsv"
python3 - "$CHARTER" > "$VOICES_TSV" <<'PYEOF'
import re, sys, unicodedata

text = open(sys.argv[1], encoding="utf-8").read()
lines = text.splitlines()

def slugify(s):
    s = s.lower()
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s or "voice"

# σπάσε σε `### ` sections
sections = []
cur = None
for ln in lines:
    if ln.startswith("### "):
        if cur is not None:
            sections.append(cur)
        cur = {"header": ln[4:].strip(), "body": []}
    elif cur is not None:
        cur["body"].append(ln)
if cur is not None:
    sections.append(cur)

out = []
for sec in sections:
    body = "\n".join(sec["body"])
    blob = sec["header"] + "\n" + body
    # μοντέλο: γραμμή «Μοντέλο: `model`» (ή «Model:»)
    m = re.search(r"(?:Μοντέλο|Model)\s*:\s*`?([A-Za-z0-9._/\-]+)`?", blob)
    if not m:
        continue
    model = m.group(1)
    # skip synthesizer-only sections (τα τρέχει το synthesize.sh)
    if re.search(r"ΣΥΝΘΕΤΗΣ|synthesi|συνθέτ", blob, re.IGNORECASE):
        continue
    # καθάρισε όνομα από αρίθμηση «1. Name — pattern: ...»
    name = re.sub(r"^\d+\.\s*", "", sec["header"])
    name = re.split(r"\s+—|\s+-\s+", name)[0].strip()
    section_text = "### " + sec["header"] + "\n" + body.strip()
    # TSV-safe: tabs/newlines → spaces στα μικρά πεδία· το section πάει base?  όχι,
    # κρατάμε section σε ξεχωριστό αρχείο για να μην σπάει το TSV.
    out.append((slugify(name), name.replace("\t", " "), model, section_text))

for i, (slug, name, model, _) in enumerate(out):
    print(f"{i}\t{slug}\t{name}\t{model}")
PYEOF

# γράψε το section κάθε voice σε ξεχωριστό αρχείο (αποφεύγει TSV escaping)
python3 - "$CHARTER" "$OUTDIR" <<'PYEOF'
import re, sys, unicodedata, os

text = open(sys.argv[1], encoding="utf-8").read()
outdir = sys.argv[2]
lines = text.splitlines()

def slugify(s):
    s = s.lower()
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s or "voice"

sections, cur = [], None
for ln in lines:
    if ln.startswith("### "):
        if cur is not None: sections.append(cur)
        cur = {"header": ln[4:].strip(), "body": []}
    elif cur is not None:
        cur["body"].append(ln)
if cur is not None: sections.append(cur)

i = 0
for sec in sections:
    body = "\n".join(sec["body"]); blob = sec["header"] + "\n" + body
    m = re.search(r"(?:Μοντέλο|Model)\s*:\s*`?([A-Za-z0-9._/\-]+)`?", blob)
    if not m: continue
    if re.search(r"ΣΥΝΘΕΤΗΣ|synthesi|συνθέτ", blob, re.IGNORECASE): continue
    name = re.sub(r"^\d+\.\s*", "", sec["header"])
    name = re.split(r"\s+—|\s+-\s+", name)[0].strip()
    sec_text = "### " + sec["header"] + "\n" + body.strip()
    open(os.path.join(outdir, f"_section-{i}.txt"), "w", encoding="utf-8").write(sec_text)
    i += 1
PYEOF

N_VOICES=$(wc -l < "$VOICES_TSV" | tr -d ' ')

# fallback roster αν <3 voices.
# Config-driven (σπόρος/τρίτοι): CE_ROSTER env → scripts/.ce-roster file → hardcoded default.
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROSTER="openai/gpt-5.4-pro google/gemini-2.5-pro anthropic/claude-opus-4.8 deepseek/deepseek-r1"
if [ -n "${CE_ROSTER:-}" ]; then
  ROSTER="$CE_ROSTER"
elif [ -f "$_SCRIPT_DIR/.ce-roster" ]; then
  ROSTER="$(grep -vE '^\s*#|^\s*$' "$_SCRIPT_DIR/.ce-roster" | tr '\n' ' ')"
else
  ROSTER="$DEFAULT_ROSTER"
fi
FALLBACK=0
if [ "${N_VOICES:-0}" -lt 3 ]; then
  echo "⚠ charter έδωσε $N_VOICES voices (<3) → roster fallback: $ROSTER" >&2
  FALLBACK=1
  : > "$VOICES_TSV"
  idx=0
  for mdl in $ROSTER; do
    slug=$(printf '%s' "$mdl" | tr '/.' '--' | tr -cd 'a-z0-9-')
    printf '%s\t%s\t%s\t%s\n' "$idx" "$slug" "$mdl" "$mdl" >> "$VOICES_TSV"
    # για το fallback, το section = όλο το charter (κοινό corpus-of-pattern)
    cp "$CHARTER" "$OUTDIR/_section-$idx.txt"
    idx=$((idx+1))
  done
  N_VOICES=$idx
fi

echo "── Council: $N_VOICES voices · MAXTOK=$MAXTOK · TEMP=$TEMP"

CORPUS_TEXT=$(cat "$CORPUS")
OK_COUNT=0
DEGRADED_COUNT=0

# ── 2. Μία κλήση/φωνή ───────────────────────────────────────────────────────
while IFS=$'\t' read -r idx slug name model; do
  [ -n "${idx:-}" ] || continue
  SECTION_FILE="$OUTDIR/_section-$idx.txt"
  SECTION=$(cat "$SECTION_FILE" 2>/dev/null || echo "")
  VOICE_OUT="$OUTDIR/voices/$slug.md"

  PROMPT="Είσαι μία φωνή μέσα σε ένα Council. Δεν αναπαράγεις πληροφορία — δένεσαι σε ΕΝΑ pattern και διαβάζεις το corpus ΑΠΟ ΤΗ ΔΙΚΗ ΣΟΥ στάση. Δεν βλέπεις τις άλλες φωνές. Απάντα ανεξάρτητα, πυκνά, με αναφορές στο corpus.

=== Η ΦΩΝΗ ΣΟΥ (pattern) ===
$SECTION

=== CORPUS ===
$CORPUS_TEXT

=== ΤΙ ΖΗΤΑΩ ===
Διάβασε το corpus ΜΕΣΑ ΑΠΟ το pattern σου. Βγάλε: (1) τι βλέπεις που οι άλλες στάσεις ΔΕΝ θα δουν, (2) πού σπάει ΠΡΩΤΟ το design, (3) μία falsifiable πρόβλεψη. Όχι summary — μετατόπιση."

  PAYLOAD=$(MODEL="$model" MAXTOK="$MAXTOK" TEMP="$TEMP" python3 -c "
import json, os, sys
print(json.dumps({
  'model': os.environ['MODEL'],
  'messages': [{'role':'user','content': sys.argv[1]}],
  'max_tokens': int(os.environ['MAXTOK']),
  'temperature': float(os.environ['TEMP']),
}))
" "$PROMPT")

  START=$(python3 -c "import time;print(time.time())")
  RESULT=$(curl -s "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Content-Type: application/json" \
    -H "HTTP-Referer: https://onlyaiam.com" \
    -d "$PAYLOAD" --max-time 300) || RESULT=""
  END=$(python3 -c "import time;print(time.time())")
  LATENCY=$(python3 -c "print(round($END-$START,2))")

  # parse + model-match assert· emit μία γραμμή status: OK|DEGRADED|ERR|EMPTY
  STATUS=$(REQ="$model" SLUG="$slug" NAME="$name" LAT="$LATENCY" \
           VOUT="$VOICE_OUT" META="$META_LINES" DLOG="$DEGRADED_LOG" \
           python3 - "$RESULT" <<'PYEOF'
import json, os, sys, re

raw = sys.argv[1]
req = os.environ["REQ"]; slug = os.environ["SLUG"]; name = os.environ["NAME"]
lat = float(os.environ["LAT"]); vout = os.environ["VOUT"]
meta = os.environ["META"]; dlog = os.environ["DLOG"]

def write_meta(model_actual, degraded, tokens, fr):
    rec = {"voice": slug, "name": name, "model_requested": req,
           "model_actual": model_actual, "degraded": degraded,
           "tokens": tokens, "latency": lat, "finish_reason": fr}
    with open(meta, "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")

try:
    d = json.loads(raw) if raw.strip() else {"error": {"message": "empty curl response"}}
except Exception as e:
    d = {"error": {"message": f"non-JSON response: {e}"}}

if "error" in d:
    write_meta("", True, 0, "error")
    with open(dlog, "a") as f:
        f.write(f"{slug}\tERR\t{json.dumps(d['error'], ensure_ascii=False)}\n")
    sys.stderr.write(f"ERR {slug} ({req}): {json.dumps(d['error'], ensure_ascii=False)}\n")
    print("ERR"); sys.exit(0)

choices = d.get("choices") or [{}]
msg = (choices[0].get("message") or {}).get("content") or ""
fr = choices[0].get("finish_reason", "?")
usage = d.get("usage", {})
tokens = usage.get("total_tokens", 0)
actual = d.get("model", "")

# model-match: το OpenRouter επιστρέφει συχνά version-date suffix ή/και
# αναδιαταγμένο όνομα (π.χ. req `anthropic/claude-opus-4.8` → actual
# `anthropic/claude-4.8-opus-20260528`). Μια απλή base-split θα έβγαζε
# false-positive DEGRADED. Άρα: token-subset match — ίδιος provider +
# ΟΛΑ τα requested tokens παρόντα στο actual (ανέχεται reorder +
# version/date suffix αλλά πιάνει πραγματική αντικατάσταση μοντέλου).
def toks(m):
    m = m.split(":", 1)[0].lower()           # κόψε routing-suffix (:free/:nitro)
    return [t for t in re.split(r"[/\-]", m) if t]
if actual.strip():
    req_t = toks(req); act_t = set(toks(actual))
    prov_req = req.split("/", 1)[0].lower()
    prov_act = actual.split("/", 1)[0].lower()
    # match: ίδιος provider + κάθε requested token (πλην provider) ∈ actual
    degraded = (prov_req != prov_act) or not all(t in act_t for t in req_t)
else:
    degraded = True

if not msg.strip():
    write_meta(actual, True, tokens, fr)
    with open(dlog, "a") as f:
        f.write(f"{slug}\tEMPTY\tfinish_reason={fr} usage={usage}\n")
    sys.stderr.write(f"EMPTY {slug} ({req}): finish_reason={fr}\n")
    print("EMPTY"); sys.exit(0)

flag = ""
if degraded:
    flag = f"  [DEGRADED: got {actual}, wanted {req}]"
    with open(dlog, "a") as f:
        f.write(f"{slug}\tDEGRADED\tgot={actual} wanted={req}\n")

with open(vout, "w", encoding="utf-8") as f:
    f.write(f"# Council Voice — {name}{flag}\n")
    f.write(f"- model_requested: `{req}`\n")
    f.write(f"- model_actual:    `{actual}`\n")
    f.write(f"- degraded: {str(degraded).lower()}\n")
    f.write(f"- tokens: {tokens} · latency: {lat}s · finish_reason: {fr}\n\n")
    f.write(msg)

write_meta(actual, degraded, tokens, fr)
print("DEGRADED" if degraded else "OK")
PYEOF
)

  case "$STATUS" in
    OK)       OK_COUNT=$((OK_COUNT+1));       echo "✓ $slug ($model) OK" ;;
    DEGRADED) DEGRADED_COUNT=$((DEGRADED_COUNT+1)); echo "⚠ $slug DEGRADED (δεν μετράει ως ψήφος)" ;;
    *)        DEGRADED_COUNT=$((DEGRADED_COUNT+1)); echo "✗ $slug $STATUS" ;;
  esac
done < "$VOICES_TSV"

# ── 3. Συναρμολόγηση _council-meta.json ─────────────────────────────────────
python3 - "$META_LINES" "$OUTDIR/_council-meta.json" <<'PYEOF'
import json, sys
recs = []
try:
    for ln in open(sys.argv[1], encoding="utf-8"):
        ln = ln.strip()
        if ln: recs.append(json.loads(ln))
except FileNotFoundError:
    pass
json.dump(recs, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PYEOF

# cleanup ενδιάμεσων
rm -f "$OUTDIR"/_section-*.txt "$VOICES_TSV" "$META_LINES" 2>/dev/null || true

echo "────────────────"
echo "Council done: $OK_COUNT OK · $DEGRADED_COUNT degraded/failed"
echo "meta → $OUTDIR/_council-meta.json"
[ -s "$DEGRADED_LOG" ] && echo "degraded log → $DEGRADED_LOG" || rm -f "$DEGRADED_LOG"

# exit 1 αν <3 ανεξάρτητες (OK) φωνές — αλλιώς το Council δεν έχει βάση σύγκλισης
if [ "$OK_COUNT" -lt 3 ]; then
  echo "✗ μόνο $OK_COUNT ανεξάρτητες φωνές (<3) — δεν υπάρχει βάση σύγκλισης" >&2
  exit 1
fi
exit 0
