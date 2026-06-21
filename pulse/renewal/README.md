# renewal/ — Ο Κύκλος της Ανανέωσης

Κρατά τη μνήμη του σπόρου **in-line με την πραγματικότητα** — χωρίς να την παγώνει.
Μια φορά τη νύχτα: ανιχνεύει ποια compiled views ξεπεράστηκαν από νεότερο evidence,
και τα ξαναχτίζει από το φρέσκο ρεύμα των ιχνών.

## Αρχεία
- `CYCLE.md` — η διαδικασία (6 φάσεις), ο Iron Law, το όριο. Διάβασέ το πρώτο.
- `cycle.sh` — ο thin harness που τρέχει τις φάσεις.

## Τα τρία στρώματα (πλήρες: το αρχικό πλάνο στον owner workspace)
- **Νόμος** (zero-LLM): `../../memory/edge_extract.py` (edges) + `../../memory/recall_law.py` (βάρος) + `../../memory/stale_check.py` (το «κοίτα»).
- **Κύκλος** (hybrid): εδώ. 6 φάσεις, μηχανικό gate + resonance στη φάση ④.
- **Έκφραση** (latent): `../express/recall_offer.py` (υποδεικτικός τρόπος) + `../express/drift_gate.md` (φύλακας φωνής).

## Πώς το ενεργοποιεί ο owner
1. Reflective ίχνη ζουν σε έναν φάκελο (π.χ. `../../memory/`).
2. Compiled views στο `../../memory/views/` (δες `_TEMPLATE.md`).
3. Cron μια φορά τη νύχτα: `bash cycle.sh --reflective <dir> --views ../../memory/views`.
4. Default zero-LLM (flag-only). Για αυτόματη ξανα-σύνθεση: `--synthesize --max-usd N` (owner-enabled).

## Το όριο που δεν περνιέται
Το nightly view = **pointer-με-freshness, ΠΟΤΕ truth**. Η αληθινή σύνθεση
γεννιέται τη στιγμή που κάποιος ρωτά (recall_law query-time). Δες CYCLE.md § ΟΡΙΟ.
