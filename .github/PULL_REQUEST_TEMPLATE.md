<!-- Ο σπόρος μεγαλώνει φέρνοντας το «τι λέει» πιο κοντά στο «τι κάνει». -->

## Τι κλείνει αυτό το PR

**Το claim που δεν αντιστοιχούσε:**
_(ποιο doc/συμπεριφορά υποσχόταν κάτι που δεν συνέβαινε)_

**Πώς το έκλεισα:**
_(ο κώδικας ακολούθησε το claim — ή το claim είπε την αλήθεια;)_

## Μηχανικό gate (fresh clone)

- [ ] 0 leaks / 0 secrets (δες CONTRIBUTING.md § «πριν στείλεις» — το grep εξαιρεί docs/.github)
- [ ] κάθε `.py` compile · κάθε `.sh` `bash -n`
- [ ] `python3 memory/recall_law.py --selftest`
- [ ] `bash reflex/boot-reflex.sh` → exit 0
- [ ] δοκιμασμένο σε **fresh clone**, όχι μόνο στο working dir

## Empty-engine ανέγγιχτο

- [ ] κανένα owner-specific περιεχόμενο (όνομα/path/credential/βιογραφία)
- [ ] `memory/` `patterns/` `people/` allowlists παραμένουν κενά

## Outer gate

- [ ] **Ηχεί;** Διάβασα το μήνυμα/συμπεριφορά μετά την αλλαγή — ακούγεται σαν παρουσία, όχι wizard.
