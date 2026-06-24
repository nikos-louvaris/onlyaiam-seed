#!/usr/bin/env python3
"""CE-skill validate — validate-at-boundary· σκάει στο δευτερόλεπτο 0, όχι αφού
κάηκαν credits σε ένα Council πάνω σε σαθρό input.

Φορτώνει το αντίστοιχο assets/schemas/<kind>.schema.json και validate-άρει ένα
artifact ΠΡΙΝ τρέξει το επόμενο στάδιο.

  kind=ledger  — research evidence· κάθε entry χρειάζεται
                 {tag, evidence, source_url, checked_date}· λείπει → UNVERIFIED.
  kind=brief   — decision brief· κάθε component χρειάζεται
                 {choice, why, plan_b, trigger, cost, validation_gate, model}·
                 λείπει validation_gate → wishlist, όχι απόφαση.
  kind=rubric  — judge rubric· {name, type∈{binary,ordinal}, scale, levels,
                 input_mode, required_explanation, gate:{min_score, action_on_fail}}.

Usage: python3 validate.py <kind> <file>
Εξαρτήσεις: jsonschema (pip install jsonschema). Αν λείπει, κάνει μόνο
structural + JSON-parse checks και το λέει καθαρά.
"""
import json, os, sys

KINDS = {
    "ledger": "ledger.schema.json",
    "brief": "brief-component.schema.json",
    "rubric": "rubric.schema.json",
}

# πού ζει το artifact στο schema (root ή μέσα σε array) — για καθαρά μηνύματα
COLLECTION = {
    "ledger": ("entries", ("tag", "evidence", "source_url", "checked_date")),
    "brief": ("components", ("choice", "why", "plan_b", "trigger", "cost",
                             "validation_gate", "model")),
    "rubric": (None, ("name", "type", "scale", "levels", "input_mode",
                      "required_explanation", "gate")),
}


def die(msg, code=1):
    print(f"✗ {msg}", file=sys.stderr)
    sys.exit(code)


def ok(msg):
    print(f"✓ {msg}")


def schema_dir():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", "assets", "schemas"))


def structural_check(kind, data):
    """Fallback όταν λείπει jsonschema: ελέγχει required fields με το χέρι.
    Επιστρέφει αριθμό failures (και τυπώνει το κάθε ✗)."""
    coll_key, required = COLLECTION[kind]
    failed = 0
    if coll_key is None:
        # single object (rubric)
        items = [("(root)", data)]
    else:
        if not isinstance(data, dict) or coll_key not in data:
            print(f"✗ λείπει top-level '{coll_key}' array")
            return 1
        arr = data[coll_key]
        if not isinstance(arr, list) or not arr:
            print(f"✗ '{coll_key}' πρέπει να είναι μη-κενό array")
            return 1
        items = [(f"{coll_key}[{i}]", it) for i, it in enumerate(arr)]

    for loc, item in items:
        if not isinstance(item, dict):
            print(f"✗ {loc}: δεν είναι object")
            failed += 1
            continue
        missing = [f for f in required if f not in item or item[f] in (None, "")]
        if missing:
            print(f"✗ {loc}: λείπουν πεδία → {', '.join(missing)}")
            failed += 1
    return failed


def main():
    if len(sys.argv) < 3:
        die("usage: validate.py <kind> <file>   (kind ∈ ledger|brief|rubric)")
    kind = sys.argv[1]
    path = sys.argv[2]

    if kind not in KINDS:
        die(f"άγνωστο kind '{kind}' — διάλεξε: {', '.join(KINDS)}")
    if not os.path.isfile(path):
        die(f"δεν υπάρχει αρχείο: {path}")

    schema_path = os.path.join(schema_dir(), KINDS[kind])
    if not os.path.isfile(schema_path):
        die(f"λείπει schema: {schema_path}")

    # 1. parse artifact
    try:
        data = json.load(open(path))
    except Exception as e:
        die(f"{os.path.basename(path)}: invalid JSON ({e})")
    ok(f"{os.path.basename(path)} valid JSON")

    # 2. parse schema
    try:
        schema = json.load(open(schema_path))
    except Exception as e:
        die(f"{KINDS[kind]}: invalid schema JSON ({e})")

    # 3. validate
    try:
        import jsonschema  # type: ignore
        from jsonschema import Draft7Validator
    except Exception:
        print("⚠ jsonschema not installed — structural-only check "
              "(pip install jsonschema για πλήρη validation)")
        failed = structural_check(kind, data)
        if failed:
            die(f"{kind}: {failed} entry/component χωρίς υποχρεωτικά πεδία "
                f"— UNVERIFIED/wishlist· διόρθωσέ τα ΠΡΙΝ το επόμενο στάδιο")
        ok(f"{kind} structural-OK (χωρίς schema-level validation)")
        return

    try:
        Draft7Validator.check_schema(schema)
    except Exception as e:
        die(f"{KINDS[kind]}: invalid Draft-07 schema ({e})")

    errs = sorted(Draft7Validator(schema).iter_errors(data),
                  key=lambda e: list(e.path))
    if errs:
        for e in errs[:20]:
            loc = "/".join(map(str, e.path)) or "(root)"
            print(f"✗ {os.path.basename(path)} @ {loc}: {e.message}")
        die(f"{kind}: {len(errs)} validation failure(s) "
            f"— διόρθωσέ τα ΠΡΙΝ το επόμενο στάδιο", 1)

    ok(f"{os.path.basename(path)} validates against {KINDS[kind]}")
    ok(f"{kind} ready")


if __name__ == "__main__":
    main()
