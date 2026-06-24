# Source Rubric — φρεσκάδα ως gate, όχι στολίδι

_Πηγή: phygital-experiences/cogeng/maturity-research/RESEARCH-PLAN.md. Εντολή Νίκου: «δεν βάζεις πράσινο/κίτρινο/κόκκινο σε κάτι που δεν είναι.»_

## Ο κανόνας

Το maturity/confidence tag **ΔΕΝ είναι γνώμη** — είναι ισχυρισμός που πρέπει να τεκμηριωθεί με **φρέσκια πηγή**. Αν δεν τεκμηριώνεται → **⬜ UNVERIFIED, όχι μαντεψιά.** «Καλύτερα "δεν επιβεβαίωσα" παρά ψεύτικο πράσινο.»

## Τα tags

- **🟢 PRODUCTION/VERIFIED** — απαιτεί ΚΑΙ τα 4 (όπου εφαρμόζεται): shipping/active-maintained · χρήσιμη απόδοση (real-time/ακρίβεια) · commodity hardware · πραγματικό deployment. Με πηγή+ημερομηνία.
- **🟡 PROBABLE** — current/named αλλά λείπει id/date/maintenance verification. π.χ. paper χωρίς arXiv-id, repo χωρίς last-commit έλεγχο.
- **⬜ UNVERIFIED** — δεν τεκμηριώθηκε. Ρητό work-item, ΟΧΙ κρυμμένο κενό.

## Κάθε query ζητά τα 6 μαζί
τρέχουσα έκδοση/date · GitHub last-commit/stars · πραγματικά deployments · fps@res (ή latency) · hardware (commodity/exotic) · license.

## Το ledger
Τελικό artifact = `ledger.json`: μία γραμμή/tech `{tag, evidence, source_url, checked_date}`. `validate.py ledger` σκάει (exit 1) αν λείπει πεδίο. Εφαρμόζεις tags ΜΟΝΟ σε ό,τι τεκμηριώθηκε.

## ⚠️ Ο rubric ισχύει ΚΑΙ στα δικά σου citations (W1, 24/6)
Στο CE self-research, τα anti-sycophancy papers μπήκαν αρχικά 🟢 «named paper» — λάθος. «Named in a Perplexity answer» ≠ verified arXiv-id. Με τον δικό σου κανόνα = 🟡 μέχρι id. **Η αυταπάτη που προειδοποιείς εμφανίζεται πρώτα στο δικό σου ledger.** Resolve ids ΠΡΙΝ χτίσεις επάνω τους.

## Honesty over completeness
Το family-research έγραψε ρητά «No public benchmark — zero direct» αντί να μαντέψει. Anti-pattern να αποφύγεις: «80% του stack υπάρχει» (το story-council το χτύπησε ως την πιο επικίνδυνη φράση). Μη δηλώνεις ωριμότητα που δεν μέτρησες.
