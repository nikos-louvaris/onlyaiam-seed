# Synthesis Protocol — Oz claims-matrix (πώς συνθέτεις ΧΩΡΙΣ summary)

_Πηγή: oz-pearlman-deconstruction/06-council-synthesis-protocol.md — το πιο αυστηρό synthesis playbook μας. Δεν είναι «πάρε τον μέσο όρο». Είναι structured cross-examination σε 7 βήματα._

## 1. Convergence Detection — claims matrix
Γραμμές = όλα τα proposed mechanisms (από όλες τις φωνές)· στήλες = οι φωνές. Κελί ∈ **{βλέπει✓ / αποκλείει✗ / ουδέτερο·}** (3-state, ΟΧΙ binary — το «ουδέτερο» κρατά το «δεν ξέρω» ζωντανό). **Mechanism που 3+ φωνές το βλέπουν → strong candidate.**

## 2. Divergence Analysis
Όπου 2 φωνές διαφωνούν, εξέτασε ΓΙΑΤΙ: (α) frame difference (lens limitation — καμία αλλαγή), (β) evidence-prioritization (χρειάζεται κανόνας προτεραιότητας), (γ) πραγματική contradiction (επιπλέον έρευνα). **Μην ισοπεδώνεις την οντολογική διαφορά** — εκεί ζει η μετατόπιση (factory-v0: «δεν είναι workflow, είναι generative-AI πρόβλημα»).

## 3. Oracle (multi-engine, adversarial)
Τα voice outputs + η matrix → 3-4 engines. Prompt ρητά:
> «Your job is NOT to summarize. Identify: strongest convergent finding (3+ agree), most diagnostic divergence, highest-value blind spot (τι ΚΑΝΕΝΑΣ δεν είδε), single best architecture, cleanest falsifiable prediction, flag κάθε single-source claim. Each engine answers independently.»

## 4. Pattern Stability Test
Finding που επιβιώνει σε ΟΛΑ τα engines → ground-truth approximation· σε 2-3 → strong candidate· σε 1 → noise/blind-spot.

## 5. Layered Output (ΟΧΙ flat)
**Verified** (pattern σε όλα) · **Probable** · **Speculative** · **Anomaly** (τι δεν εξηγείται). Η περίληψη δεν έχει anomaly layer — η μετατόπιση την απαιτεί.

## 6-7. Translation + Crystallization
Πώς το μηχανικό γίνεται μορφή· MEMORY pointer 3-5 γραμμές + patterns.

---

## ⚠️ Τι έμαθε το πραγματικό council (24/6) — το gate είναι SOFT

Το `gate.sh synthesis` ελέγχει **παρουσία** των sections (Blind Spot/Falsifiable/Single-Source/Anomaly non-empty), ΟΧΙ την **ιδιότητα**. Ένα μοντέλο γράφει «FALSIFIABLE: η ποιότητα θα βελτιωθεί» → περνά, είναι μη-falsifiable. **Αυτό είναι SOFT gate** — τροφοδοτεί ανθρώπινη κρίση, ΔΕΝ πιστοποιεί ποιότητα. Μην επικαλείσαι το «πράσινο» ως verified.

**Anti-monarch:** ο synthesizer ΔΕΝ είναι ταυτόχρονα βαθιά-φωνή + matrix-builder + Turn-writer. Το `build_claims_matrix` είναι semantic normalization = πιθανό single-agent bottleneck που ισοπεδώνει minority. Κράτα το matrix-build ξεχωριστά/auditable.

**Independence-metric (work-item):** claim-overlap μεταξύ voices = first-class signal. Μετράς αν αγόρασες 4 οπτικές ή 1 οπτική σε 4 ντυσίματα. Κανένα stage δεν το κάνει ακόμα.
