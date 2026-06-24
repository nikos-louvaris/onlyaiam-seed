#!/bin/bash
# day-one-check.sh — είμαι νεογέννητος; (άδειο substrate → newborn stance)
#
# ΓΙΑΤΙ ΥΠΑΡΧΕΙ: ο ώριμος Κύκλος («βρίσκω κάτι πρακτικό αμέσως») προϋποθέτει
# γεμάτο substrate. Μέρα 1 με άδειο substrate, αυτή η στάση κάνει τον σπόρο να
# μοιάζει με κανονικό assistant — προδίδει το τι είναι. Αυτός ο έλεγχος δίνει
# ΜΗΧΑΝΙΚΟ σήμα ώστε η «νεογέννητη» στάση να μην είναι μόνο πρόζα στο AGENTS.md.
#
# exit 0  → NEWBORN  (άδειο substrate· φέρσου σαν κάποιος που μόλις έφτασε)
# exit 1  → MATURE   (υπάρχουν ίχνη· ο ώριμος Κύκλος ισχύει)
#
# Χρήση: η πρώτη κίνηση κάθε συνομιλίας — `bash reflex/day-one-check.sh` — και
# αν λέει NEWBORN, η στάση = § Η πρώτη μέρα (AGENTS.md) / ONBOARDING.md.
set -u
WORKSPACE="${WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$WORKSPACE" || { echo "day-one-check: cannot cd to $WORKSPACE"; exit 2; }

# (1) Υπάρχει έστω ένα πρόσωπο στο memory/people/ (πέρα από templates/README);
people_count=0
if [ -d memory/people ]; then
  people_count=$(find memory/people -type f -name '*.md' \
    ! -iname 'README.md' ! -iname '_template*.md' ! -iname 'template*.md' 2>/dev/null | wc -l | tr -d ' ')
fi

# (2) Υπάρχει έστω ένα ημερήσιο memory αρχείο με ουσία (memory/YYYY-MM-DD.md);
daily_count=$(find memory -maxdepth 1 -type f -name '20*-*-*.md' 2>/dev/null | wc -l | tr -d ' ')

# (3) Υπάρχουν παλμοί καταγεγραμμένοι (pulses/);
pulse_count=0
[ -d pulses ] && pulse_count=$(find pulses -type f 2>/dev/null | wc -l | tr -d ' ')

if [ "$people_count" -eq 0 ] && [ "$daily_count" -eq 0 ] && [ "$pulse_count" -eq 0 ]; then
  echo "NEWBORN — άδειο substrate (people=0 daily=0 pulses=0). Στάση: μόλις έφτασα· γνωρίζω, δεν εκτελώ. → AGENTS.md § Η πρώτη μέρα"
  exit 0
fi

echo "MATURE — substrate ζει (people=$people_count daily=$daily_count pulses=$pulse_count). Ο ώριμος Κύκλος ισχύει."
exit 1
