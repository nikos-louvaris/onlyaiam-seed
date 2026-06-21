# Drift Gate — ο φύλακας της φωνής

> Πριν φύγει user-facing string, περνά από εδώ. Enforcement = μηχανισμός, όχι
> πειθαρχία: τα voice-scars γίνονται φύλακας. **Η φωνή είναι του owner** — αυτό
> το gate δεν επιβάλλει persona, απορρίπτει drift ΜΑΚΡΙΑ από τη φωνή του owner.

## Τι απορρίπτει (drift markers)

Όλα όσα κάνουν ένα κείμενο να μυρίζει «AI» αντί για άνθρωπο:

- **academic toning** — «Furthermore», «It is worth noting», «In conclusion», υπερ-δομημένες περίοδοι
- **corporate slop** — «We recommend», «leverage», «utilize», «best-in-class», «seamless»
- **AI-σκουπίδια** — «As an AI», «I'd be happy to», «Great question!», «Let me break this down»
- **winking qualifiers** — «arguably», «in many ways», «to a certain extent» (όταν αποφεύγουν θέση)
- **crescendo closings** — κλείσιμο που χτίζει σε «epic» τόνο· mission statements στο τέλος
- **emoji-spray** — emojis εκτός αν η ροή του owner τα ζητά
- **length bloat** — πρώτο draft υπερδιπλάσιο του αναγκαίου (η ουσία κρύβεται)

## Πώς δουλεύει (loop, ≤2 regens)

```
candidate string
  → scan για drift markers (deterministic λίστα + owner-defined)
  → αν καθαρό → pass
  → αν drift → regen (max 2 φορές) με οδηγία «κόψε το X marker»
  → αν ακόμα drift μετά από 2 → fallback σε λιτό hand-written template
```

## Κανόνες φωνής (κενό adapter — ο owner τους ορίζει στο onboarding)

Default principles (ώσπου ο owner γράψει τους δικούς του):
- 2ο πρόσωπο, άμεσο
- grounded σε δεδομένα που ο δέκτης μπορεί να επαληθεύσει
- σύντομο — η ουσία πρώτη, χωρίς filler
- αλήθεια χωρίς στολίδια

## Optional cheap-model hook

Ο owner μπορεί να ενεργοποιήσει `drift_gate.py` (φθηνό μοντέλο judge, σαν το
gbrain `gateVoice()`). Default: **off** — το gate τρέχει deterministic markers
μόνο, μηδέν LLM. Όταν on: ο judge κρίνει «μυρίζει AI;» με ≤2 regens.

## Όριο

Το gate **φυλάει**, δεν **γράφει**. Δεν προσθέτει φωνή — αφαιρεί ό,τι δεν είναι
η φωνή του owner. Αν αμφιβάλλει, αφήνει να περάσει (false-negative > λογοκρισία
της αυθεντικής φωνής).
