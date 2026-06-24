# The Evidence — τι απέδειξε το πραγματικό council (24/6)

_Το CE skill χτίστηκε με CE: research-via-loopcraft → independent auditor → 4-model council πάνω στον ίδιο του τον σχεδιασμό → synthesis → brief → Turn. Αυτό το αρχείο = τι κερδήθηκε, ώστε να μην ξαναχαθεί._

## Το council ήταν αληθινό (όχι theater)
4 μοντέλα, 4 patterns, verified live (model-assert: date-suffixes `gpt-5.4-pro-20260305`, `claude-4.8-opus-20260528` σωστά δεκτά — κανένα false-positive). **Ο Opus red-teamer προέβλεψε** ότι ≥3/4 θα επαινούσαν τη heterogeneity-as-defense. **2 φωνές την προκάλεσαν ανεξάρτητα → η πρόβλεψη διαψεύστηκε** → απόδειξη αληθινής adversarial διαφοροποίησης.

## Τα 3 Verified findings (3+ φωνές, ανεξάρτητα)

1. **Το πρώτο break είναι το Synthesis gate, ΟΧΙ το model-assert.** Και οι 4: το `gate.sh synthesis` ελέγχει παρουσία section-titles, όχι ιδιότητα. Ψεύτικο πράσινο. → **synthesis gate = SOFT, ρητά.**

2. **Το model-assert λύνει μόνο transport independence.** 4 στρώματα ανεξαρτησίας (transport·cognitive·epistemic·decision) — χτίστηκαν 2.5. Διαφορετικά **βάρη** ≠ διαφορετικές **οπτικές**.

3. **Heterogeneity μοντέλων ≠ epistemic independence.** Correlated training/RLHF → «correlated δείγματα που μοιάζουν ανεξάρτητα επειδή έχουν διαφορετικά ονόματα». Το πρόβλημα είναι επιστημολογικό, όχι μηχανικό.

## Η Μετατόπιση (The Turn)
> **Το CE skill ΔΕΝ είναι consensus engine. Είναι disagreement-preservation engine με controlled recapture.**

Συνέπειες (στο `5-brief/BRIEF.json`):
- model-assert/ledger/schema = **HARD** (μηχανικό exit 1).
- synthesis-quality/Turn = **SOFT** → resonance («ηχεί;», μόνο άνθρωπος).
- Κάθε gate παίρνει ρητό HARD/SOFT tag. Καμία ψεύτικη μηχανική βεβαιότητα.

## Work-items (v2 — single-source, strong αλλά όχι verified)
- minority-hypothesis survival gate (gpt5): επέζησε η ουσιαστική διαφωνία μέχρι το Brief, ή την ισοπέδωσε ο matrix-builder; (provider-substitution έχει assert· ontology-substitution όχι)
- independence-metric: claim-overlap μεταξύ voices ως first-class signal (το blind-spot της σύγκλισης — κανένας single voice δεν το είδε ολόκληρο)
- matrix-build separation από synthesizer (anti-monarch)
- progressive synthesis: cheap default, --oracle on-demand (deepseek — μην over-engineer-άρεις)

## Anomaly (δεν λύνεται με script)
Πώς μετράς «independence» χωρίς να γίνεις κι εσύ ένας ακόμα correlated judge; → δείχνει προς το resonance gate. Η ειλικρινής καρδιά: τα μηχανικά gates προστατεύουν transport+structure+freshness+minority-survival — ΟΧΙ epistemic independence. **Το skill που το λέει ρητά είναι αξιόπιστο.**

Πλήρες: `projects/cognitive-engineering-skill/4-council-run/SYNTHESIS.md` + `voices/`.
