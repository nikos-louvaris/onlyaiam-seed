# The Evidence — τι απέδειξε το council

Το skill-genesis δεν σχεδιάστηκε από διαίσθηση. Χτίστηκε με CE pass πάνω στον εαυτό του:
Research (154 citations, frontier papers) → Council (4 πραγματικά διαφορετικοί vendors:
OpenAI gpt-5.4-pro, Google gemini-2.5-pro, Anthropic opus-4.8, DeepSeek r1) →
Synthesis (Opus oracle, adversarial). 24/6/2026.

## Το κεντρικό εύρημα — 4-voice convergence

**Το failure ενός generated skill είναι στο activation/routing boundary, ΟΧΙ στο reasoning.**

Τέσσερις φωνές, τέσσερις διαφορετικοί δρόμοι, ίδιο σημείο:

- **Frontier-researcher** → μέσω reproducibility failure: το retrieval που τροφοδοτεί τον
  βρόχο είναι εύθραυστο, οπότε το self-improvement «βελτιστοποιεί προς λάθος κατεύθυνση».
- **Pragmatist-engineer** → μέσω production routing: «φτιάξε καλύτερους selectors με gates»
  — ίδιο πρόβλημα σε 3 layers (source / skill / edit selection).
- **Skeptic** → μέσω adversarial ambiguity: ambiguous queries ενεργοποιούν πολλά skills
  ταυτόχρονα χωρίς tie-breaking.
- **Architect** → μέσω distributed-systems topology: το `description` είναι routing table
  σε flat namespace χωρίς scheduler.

Τέσσερις ανεξάρτητες pattern-languages που προσγειώνονται στον ίδιο δομικό τόπο = το
ισχυρότερο σήμα. Όχι echo — convergence.

## Verified claims (multi-voice, corpus-grounded)

- First failure στο activation/routing, όχι reasoning. (4 voices)
- Self-generated skills underperform human-written: **+3.3pp human vs −1.3pp self-gen**·
  ungated self-generation degrade-άρει το σύστημα. (SoK-cited, 2 voices)

## Probable

- `SKILL.md` frontmatter = trigger/dispatch contract, όχι documentation.
- Overlapping descriptions → namespace collision / activation conflict.
- Δεν υπάρχει staleness signal στο skill format σήμερα (κενό που γεμίζουμε με risk-tier).

## Το blind spot (oracle synthesis — καμία φωνή δεν το είπε ολόκληρο)

**Το routing έχει cost-asymmetry που κανείς δεν ονόμασε:** false-activation high-blast
(π.χ. skill με API key που διαρρέει) vs false-suppression volatile (frontier skill που
πάγωσε και κανείς δεν το regenerate-άρει). Διαφορετικά κόστη → διαφορετικά thresholds.

Το `Don't-use-when` και `regenerate-when` δεν είναι απλώς missing fields — είναι **λάθος
representation**. Το σωστό: cost-weighted threshold per skill class. Αυτό συνθέτει
blast-radius (Skeptic) + staleness (Architect) + gate-strictness (Pragmatist) σε ένα
**risk-tiered routing policy** — ο πυρήνας του skill-genesis.

## Falsifiable prediction (το πείραμα που λύνει τη διαφωνία)

Σε σύστημα με ≥30 generated skills, το false-activation rate κλιμακώνεται **super-linearly**
και λυγίζει στα 20–40 skills όταν ο generator είναι namespace-blind· μένει **flat** όταν
κάθε νέο description conditional-άρεται σε όλα τα υπάρχοντα. Γι' αυτό το `namespace-scan`
τρέχει σε κάθε γέννηση — όχι cached.

## Anomaly (η δομημένη σιωπή του πεδίου)

Το research έδειξε ότι deployment/latency/hardware/license fields είναι uniformly UNVERIFIED
ενώ τα benchmark fields γεμάτα. Το πεδίο μετράει ό,τι είναι φθηνό να μετρηθεί (benchmarks)
και σιωπά συλλογικά για ό,τι καθορίζει production viability. Σήμα για το incentive structure
του πεδίου — γι' αυτό το skill-genesis εμπιστεύεται primary sources με date/commit, όχι claims.
