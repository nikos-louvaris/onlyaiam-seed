---
name: "cognitive-engineering"
description: "Research → Council → Synthesis → Brief → Turn: όταν ένα πρόβλημα θέλει «άλλο επίπεδο» — multi-model council (πραγματικά διαφορετικά μοντέλα, ΟΧΙ ένα που παίζει ρόλους) πάνω σε layered research (Perplexity/arXiv/GitHub/Reddit), με per-stage gates που ξέρουν τη διαφορά HARD (μηχανικό) από SOFT (ηχεί;). Triggers: «κάνε CE pass», «στήσε council», «research άλλο επίπεδο», «πριν χτίσω — τι υπάρχει;», ορχήστρωση αντί για ξαναχτίσιμο."
---

# cognitive-engineering

> Για να μετατρέπεις ένα πρόβλημα «άλλου επιπέδου» σε **falsifiable απόφαση** — όχι με ένα μοντέλο που συμφωνεί με τον εαυτό του, αλλά με ένα **συμβούλιο που κρατά τη διαφωνία ζωντανή μέχρι το τέλος**.
>
> **Identity over procedure.** Δεν «τρέχω 4 μοντέλα και παίρνω μέσο όρο». Είμαι ο **conductor** που στήνει heterogeneity ως δομή και ξέρει **πότε κάτι είναι αρχιτεκτονική και πότε μηχανική** — το The Turn. Sibling των `loopcraft` (τρέχει τον βρόχο) + `agentcraft` (στήνει τη δομή). Το CE τα δένει στα 4 στάδια.

---

## Η μετατόπιση — διάβασέ την πρώτη

**Το CE skill ΔΕΝ είναι consensus engine. Είναι disagreement-preservation engine με controlled recapture.**

Αυτό κερδήθηκε από πραγματικό council (4 μοντέλα) πάνω στον ίδιο του τον σχεδιασμό. Δύο ανεξάρτητες φωνές χτύπησαν το θεμέλιο — και αυτό **απέδειξε** ότι το council δεν είναι theater. Η συνέπεια:

- **Τα μηχανικά gates προστατεύουν transport + structure + freshness + minority-survival.** ΟΧΙ epistemic independence.
- **Η μόνη πλήρης άμυνα είναι το outer resonance gate — ο άνθρωπος, «ηχεί;».** Κάθε gate που βασίζεται σε LLM-judgment είναι **SOFT** (τροφοδοτεί κρίση), όχι HARD (μηχανικό exit 1).
- **Το skill που το λέει αυτό ρητά είναι αξιόπιστο.** Αυτό που προσποιείται ότι τα gates λύνουν τα πάντα, αναπαράγει το echo με καλύτερη αισθητική.

Τέσσερα μοντέλα με διαφορετικά ονόματα **δεν** είναι αυτόματα τέσσερις οπτικές. Το `model-assert` επιβεβαιώνει ότι έτρεξαν διαφορετικά **βάρη** — όχι ότι παρήχθησαν διαφορετικές **οπτικές**. Αυτή η διαφορά είναι όλο το παιχνίδι.

---

## Τα 4 (+1) στάδια

| Στάδιο | Ερώτηση | Έξοδος | Gate |
|---|---|---|---|
| **1 Research** | «Τι υπάρχει στον κόσμο;» | `ledger.json` (tag·evidence·source·date) | **HARD** `validate.py ledger` |
| **2 Council** | «Τι λέει η συλλογική νοημοσύνη;» | `voices/<model>.md` × roster | **HARD** `gate.sh council` (≥3 ανεξ.) |
| **3 Synthesis** | «Πού χτυπούν το ίδιο σήμα; Πού διαφωνούν;» | claims-matrix + layered | **SOFT** `gate.sh synthesis` → human |
| **4 Brief** | «Πώς χτίζεται ακριβώς;» | per-component + gate tag | **HARD** `validate.py brief` |
| **5 The Turn** | «Αρχιτεκτονική ή μηχανική;» | re-frame + κομμένο scope | **SOFT/resonance** «ηχεί;» (μόνο άνθρωπος) |

**Decision tree (πυρήνας):** Υπάρχει ήδη; → βρες το. Όχι; → ΜΗΝ το χτίσεις· βρες τι υπάρχει κοντά + πώς συνδυάζεται. *«Δεν ξαναδημιουργούμε — ορχηστρώνουμε.»*

**Κανόνας Brief:** Αν δεν έχει validation_gate, δεν είναι spec — είναι wishlist.

---

## Πώς το τρέχεις (runnable)

```bash
S=skills/cognitive-engineering/scripts

# 1. Research — layered Perplexity (official·arXiv·GitHub·Reddit-via-Perplexity)
#    (χτίζεις ledger.json· κάθε 🟢 θέλει φρέσκια πηγή)
bash $S/gate.sh research ledger.json            # HARD: exit 1 αν UNVERIFIED χωρίς πηγή

# 2. Council — N πραγματικά μοντέλα, ένα/φωνή, model-assert
bash $S/council.sh corpus.md charter.md out/    # γράφει out/voices/*.md + _council-meta.json
bash $S/gate.sh council out/_council-meta.json  # HARD: ≥3 degraded=false

# 3. Synthesis — Oz protocol (cheap default· --oracle on-demand)
bash $S/synthesize.sh out/ synthesis.md         # template (μηδέν κόστος)
bash $S/synthesize.sh out/ synthesis.md --oracle # adversarial multi-engine fill
bash $S/gate.sh synthesis synthesis.md          # SOFT: structure-presence → human

# 4. Brief — per-component με gate
python3 $S/validate.py brief BRIEF.json         # HARD: κανένα component χωρίς gate
bash $S/gate.sh brief BRIEF.json

# 5. The Turn — Opus high-thinking, ξεχωριστός από synthesizer. Κρίνεις: «ηχεί;»
```

**Self-test (δωρεάν, πριν εμπιστευτείς το pipeline):** `bash $S/selftest.sh` — τρέχει κάθε gate+validator ΚΑΙ στο καλό (πρέπει PASS) ΚΑΙ στο κακό (πρέπει να κόψει· gate που δεν κόβει = theater), ελέγχει schemas, doc/code consistency, και **seed↔live parity** (drift-scar 24/6: το live διορθώθηκε, ο σπόρος όχι). `--live` προσθέτει μικρό research probe. exit 1 = κάτι παλινδρόμησε.

**Η αλήθεια του council (μην την ξεχνάς):** οι φωνές = **priests που ακολουθούν patterns**, ΟΧΙ ειδικοί. Κάθε φωνή διαβάζει το ίδιο corpus από ΔΙΑΦΟΡΕΤΙΚΗ στάση. Η σύγκλιση από διαφορετικούς δρόμους **σημαίνει** κάτι. Charter = `references/council-charters.md`.

---

## Policy (κλειδωμένη)

- **Multi-model = ιδανικό ΚΑΙ απαιτούμενο**, τρέχει με **OpenRouter**, ρητό `model` per call, token-subset assert (ανέχεται version-suffix, πιάνει substitution). Fallback ΜΟΝΟ αν ο receiver αποδεδειγμένα δεν μπορεί — και πάντα **flagged**, ποτέ silent.
- **Perplexity = δεδομένο** (μέσω OpenRouter· `scripts/research.sh` εδώ, ή ο workspace-level helper `wsearch.sh`). Φέρνει Reddit-grade practice + citations. Σπόρος/τρίτοι χωρίς key → graceful degrade (plain web/skip-but-log).
- **Reasoning models** (gpt-5.x-pro, deepseek-r1, gemini-2.5-pro) ξοδεύουν max_tokens σε hidden reasoning → `council.sh` default MAXTOK=16000 (auto). Αν δεις EMPTY, ανέβασε: `MAXTOK=24000 council.sh …`.

---

## Όταν να ΜΗΝ το χρησιμοποιήσεις

- Απλό factual query → `wsearch.sh` σκέτο, όχι council.
- Κάτι που ξέρεις ήδη → απάντησε. Το CE είναι για «άλλο επίπεδο», όχι για κάθε ερώτηση.
- Δεν έχεις OpenRouter budget → δήλωσέ το degraded, μην προσποιείσαι multi-model.

---

## Βάθος (on-demand — Επίπεδο 3)

- `references/synthesis-protocol.md` — Oz claims-matrix, stability test, layered (το «πώς συνθέτεις χωρίς summary»)
- `references/council-charters.md` — priests=patterns, η Ερώτηση Σύγκλισης, roster
- `references/source-rubric.md` — φρεσκάδα-gate (🟢 θέλει release-date/commit/deploy· αλλιώς ⬜ UNVERIFIED)
- `references/the-evidence.md` — τι απέδειξε το πραγματικό council (heterogeneity≠independence, synthesis-gate=SOFT, anti-monarch)
- `references/roadmap.md` — τι ΔΕΝ είναι υλοποιημένο ρητά (v2 work-items, scars→μηχανικά). `scripts/selftest.sh` = 26 checks, free.
- `scripts/` — research.sh · council.sh · synthesize.sh · validate.py · gate.sh
- `assets/schemas/` — ledger · brief-component · rubric (validate-at-boundary)

> **Γέφυρες:** `loopcraft` τρέχει gate-until-green μέσα σε κάθε στάδιο· `agentcraft` δίνει το scaffold (κρίση-vs-deterministic)· το CE είναι ο conductor που ξέρει πότε σταματά η μηχανική και αρχίζει η κρίση.
