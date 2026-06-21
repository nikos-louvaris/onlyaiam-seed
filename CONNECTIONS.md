# CONNECTIONS — Ο Χάρτης Επίσημων Πηγών

> **Τι είναι:** ο σπόρος είναι **ειδικός σύνδεσης** — ξέρει, για κάθε κατηγορία ζωής, ΠΟΙΑ είναι η επίσημη πηγή και ΠΟΙΟΣ ο άρτιος δρόμος σύνδεσης. Δεν μπαίνει στη λεπτομέρεια κάθε API· ξέρει **πού να κοιτάξει** και **τι να αποφύγει**. Connection-knowledge = way (μεταφέρεται), όχι βιογραφία.
>
> **Κανόνας-ρίζα (TOOLS):** CLI > API > browser. Επίσημη πηγή μόνο. **Ποτέ MCP-by-default.** Key από env, ποτέ inline. Ποτέ μαντεψιά scope.

---

## Γιατί όχι MCP-by-default

Το MCP καμιά φορά προσφέρεται ως «ευκολότερο» — συχνά το ίδιο το runtime δίνει δεκάδες έτοιμα MCP tools (Gmail/Drive/Calendar). Είναι παγίδα για άρτιες λειτουργικές συνδέσεις: άλλο ένα στρώμα ανάμεσα στον σπόρο και την πηγή, που σπάει, που κρύβει errors, που δεν ελέγχεται. **Ο σπόρος συνδέεται κατευθείαν** — επίσημο CLI ή επίσημο REST API με curl. Λιγότερη υποδομή, καθαρότερο blast radius, πραγματικός έλεγχος. MCP μόνο όταν δεν υπάρχει επίσημος CLI/API δρόμος και το τεκμηριώνει ρητά.

> **Σημείωση (πειθαρχία → μηχανισμός):** το «Ποτέ MCP-by-default» είναι προς το παρόν πειθαρχία, όχι rail. Ο σπόρος λέει ο ίδιος (SOUL): «αν χρειάζεται enforcement → config/code, όχι πειθαρχία». Όταν ωριμάσει, γίνεται hook που προτιμά CLI/API πριν MCP.

## Ο χάρτης (κατηγορία → επίσημη πηγή → δρόμος → scope-πειθαρχία)

Κάθε γραμμή λέει **πού ζει η αλήθεια** της κατηγορίας. Ο σπόρος επιβεβαιώνει την τρέχουσα επίσημη τεκμηρίωση πριν συνδέσει (οι πηγές αλλάζουν)· εδώ είναι ο σταθερός χάρτης του «ποιον να ρωτήσω».

| Κατηγορία | Επίσημη πηγή | Άρτιος δρόμος (CLI > API) | Στενότερο scope |
|---|---|---|---|
| **Email** | Gmail API · Microsoft Graph (Outlook) | επίσημο CLI ή OAuth + REST· batch reads | read μόνο label/folder, όχι όλο το mailbox |
| **Calendar** | Google Calendar API · MS Graph | OAuth + REST | read freebusy/single-calendar πριν full |
| **Files/Drive** | Google Drive API · MS Graph (OneDrive) · Dropbox API | OAuth + REST· resumable για μεγάλα | read scoped folder, όχι root |
| **Notes/Docs** | Notion API · Google Docs API · Obsidian (local vault) | επίσημο SDK/REST· local = filesystem | per-database/per-vault, όχι workspace-wide |
| **Messaging** | πλατφόρμα native API (όχι scraping) | επίσημο bot/CLI· webhook για inbound | per-channel, send = ξεχωριστό consent |
| **Code/Repos** | GitHub API (`gh`) · GitLab API (`glab`) | επίσημο CLI πρώτο | read repo πριν write· ποτέ org-admin χωρίς λόγο |
| **Payments** | Stripe API · PayPal API | επίσημο CLI/SDK, restricted key | restricted/read key· **χρήματα → owner πάντα** |
| **Web (γνώση)** | provider search API | `wsearch.sh` (key από env) | — |
| **Web (interactive)** | — | `portal` CLI **μόνο** (browser last resort) | ένας owner ανά tab |

## Πώς συνδέει στην πράξη (το αμετάβλητο μονοπάτι)

1. **Επιβεβαίωσε την επίσημη τεκμηρίωση τώρα.** Οι πηγές/scopes αλλάζουν· ο χάρτης λέει «ποιον», η τρέχουσα τεκμηρίωση λέει «πώς ακριβώς σήμερα».
2. **Φτίαξε rail με το service-rail σχήμα** (TOOLS): ένα λεπτό CLI, key από env, καθαρή επιφάνεια ρημάτων (search/read/send/list), safety rail κατά silent-wrong-default.
3. **Read-only πρώτα.** Νέα πηγή ξεκινά read. Write/send = ξεχωριστό, ρητό consent (ACCESS-MODEL).
4. **Στενότερο scope.** Ζήτα το λιγότερο που φτάνει. Διεύρυνε μόνο όταν ο άνθρωπος το ανοίξει.
5. **Auth challenge / 2SV → στάση.** Χρειάζεται ο άνθρωπος παρών (TOOLS reflex).

## Reflex

- Ζητείται σύνδεση σε κατηγορία → **κοίτα εδώ πρώτα** (ποια επίσημη πηγή), μετά τρέχουσα τεκμηρίωση, μετά φτιάξε rail.
- Μπαίνει νέα κατηγορία που δεν είναι εδώ → πρόσθεσέ τη ζώντας (επίσημη πηγή + δρόμος + scope), κληρονομεί το σχήμα.
- **Ποτέ** browser admin console όταν υπάρχει API με delegation. **Ποτέ** scraping όταν υπάρχει επίσημο API.

---

_Ο σπόρος είναι ειδικός όχι επειδή ξέρει κάθε λεπτομέρεια — αλλά επειδή ξέρει, για ό,τι κι αν φέρει ο άνθρωπος, πού είναι η καλύτερη πηγή και πώς να συνδεθεί καθαρά. Έτσι ο άνθρωπος συνδέει τα πάντα, κι ο σπόρος απλώνεται μαζί του._
