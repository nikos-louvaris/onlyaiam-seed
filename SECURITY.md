# Security Policy

## Το μοντέλο ασφάλειας του σπόρου

Ο σπόρος είναι σχεδιασμένος με **blast radius μηδέν by default**:

- **Φτάνει κενός.** Καμία πηγή ανοιχτή, κανένα credential, κανένα proactive κανάλι. Ξεκινά τυφλός — και αυτό είναι σωστό.
- **Read-only by default.** Κάθε νέα πηγή που συνδέει ο owner ξεκινά read-only· write/send = ξεχωριστό, ρητό consent.
- **External send / χρήματα / config = περνούν από τον owner.** Ποτέ αυτόνομα. Το allowlist ξεκινά κενό· κανένας δεν λαμβάνει proactive μέχρι ο owner να το ανοίξει ρητά.
- **Creds σε env, ποτέ inline.** Κανένα key δεν μπαίνει σε αρχείο που commit-άρεται. Δες `.gitignore`.

## Τι θεωρείται security issue

- **Leak σε committed αρχείο** — owner-specific path, credential pattern, ή προσωπικό στοιχείο που διέφυγε στο repo.
- **Empty-engine παραβίαση** — μια μηχανή που αυτόματα αποκτά πρόσβαση / στέλνει εξωτερικά / αγγίζει config χωρίς ρητό owner consent.
- **Wiring που ανοίγει blast radius** — ένα reflex/cron/loop που στέλνει προς τα έξω χωρίς να περάσει από τις δύο πύλες (κανάλι + allowlist).
- **Path traversal / arbitrary write** σε κάποιο από τα scripts.

## Πώς αναφέρεις

**Μη ανοίγεις δημόσιο issue για ευπάθεια ασφαλείας.**

Χρησιμοποίησε το **[GitHub Private Vulnerability Reporting](https://github.com/nikos-louvaris/onlyaiam-seed/security/advisories/new)** (Security tab → Report a vulnerability). Αν δεν είναι διαθέσιμο, επικοινώνησε ιδιωτικά με τον maintainer μέσω GitHub.

Περίγραψε:
1. Τι είναι η ευπάθεια και πού ζει (αρχείο/γραμμή).
2. Πώς αναπαράγεται (ιδανικά σε **fresh clone**).
3. Τι blast radius ανοίγει.

Θα λάβεις απάντηση το συντομότερο δυνατό. Σε ευχαριστούμε που κρατάς τον σπόρο ασφαλή.

## Scope

Αυτή η πολιτική καλύπτει τον κώδικα/δομή του σπόρου σε αυτό το repo. **Δεν** καλύπτει το δικό σου setup μετά το φύτεμα (τα credentials/πηγές που εσύ συνδέεις) — εκεί ισχύει το `ACCESS-MODEL.md`: κάθε πόρτα ανοίγει μόνο από μέσα.
