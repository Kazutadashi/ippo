# Data principles

Ippo exists to collect good longitudinal data: years of everyday
observations that a person, a statistician or a researcher can analyse
with confidence. The screens matter, because data that is a chore to log
is never logged, but **the data is the product**. Every change to the
app is judged first by what it does to the data.

These principles are binding. `docs/data-format.md` says exactly how
the data is stored; this page says why, and what every new feature must
respect. When a principle and convenience disagree, the principle wins;
when a principle must change, change it here first.

The reader to keep in mind: someone who has never seen Ippo, opens an
export years from now, and must be able to trust and understand every
value without asking anyone.


## 1. Record observations, not judgements

Store what happened ("went to bed at 23:40", "8 reps"), never a verdict
("on time", "good workout"). Goals, targets and scores are kept apart
and worked out when shown, so changing a goal never changes history.

## 2. Missing is never zero

A value nobody entered is absent, not 0, `false` or an empty string.
Wherever "not logged" and "none" could be confused, the data keeps them
apart:

- a habit's `false` ("I did not") versus no entry ("I did not say");
- a nutrient a label did not give versus 0 g.

A table that adds things up says whether its total is complete
(`<nutrient>_complete`).

## 3. Raw values, fixed units, standard codes

- Values are stored as measured or typed, in one fixed unit, written
  in the field name (`weight_kg`) and given as a UCUM code in the
  codebook. Units are converted for display only.
- Values that are copies at a moment (a food entry's nutrients) are
  copied, so editing the food later never rewrites past days.
- Every measure that has a code in a recognised vocabulary carries it
  in the codebook: INFOODS and USDA FoodData Central for nutrients,
  LOINC for clinical measures, UCUM for units. A code is added only
  after checking it against the official source; an unconfirmed code is
  left blank, never guessed.

## 4. Time is exact, local and explained

- Every moment is RFC 3339 with its offset: the exact instant and the
  local clock time in one value.
- Each event names the device's IANA time zone, so daylight saving and
  travel can be told apart.
- Each entry says which day it is about (`date`), separately from when
  it was typed (`recorded_at`). A day lasts until 05:00 the next
  morning, in every module.

## 5. Provenance on everything

Every event says which device wrote it, when, and with which app version.
Every thing has a stable UUIDv7 that never changes, so renaming
something never breaks its history. Nothing is overwritten: changes and
deletions are new events, so any past state can be rebuilt.

## 6. Open, plain, documented formats

- The raw data is UTF-8 JSON Lines that anyone can read without Ippo.
- The Python package turns it into tidy tables (one row per
  observation, one column per variable) and exports CSV, Apache Parquet,
  a Frictionless Data Package (`datapackage.json`) and a codebook.
- Every column of every table is described in the codebook
  (`python/ippo/codebook.py`); a test fails if a column is not.
- `example-data/` holds every awkward case, and the app's tests and the
  Python tests must get the same answers from it.

## 7. The format changes carefully, and never silently

- Additions (new events, new optional fields) keep format version 1, and
  older readers skip what they do not know.
- A change that would make old data mean something else needs a new
  format version and a converter that carries old data over, checked by
  tests. Breaking the format is allowed when it makes the data
  clearly better; losing or quietly changing data is not.
- Every change to the format updates, together: `docs/data-format.md`,
  the app, the Python package and its codebook, `example-data/`, and
  both test suites.


## Checklist for a new feature that records data

- [ ] It records raw observations, with a `date` when it is about a day.
- [ ] "Not logged" can be told apart from "none" or "no".
- [ ] Units are fixed and in the field name; the codebook gives the UCUM
      code, and a verified standard code where one exists.
- [ ] It has a tidy table in the Python package, with every column in
      the codebook.
- [ ] `docs/data-format.md`, `example-data/` and both test suites are
      updated together.
