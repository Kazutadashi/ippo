# SPDX-License-Identifier: GPL-3.0-or-later
"""The codebook: what every column of every table means.

For each column it gives:

- ``type``: a Frictionless Table Schema type (``string``, ``integer``,
  ``number``, ``boolean``, ``date``, ``datetime``, ``any``), which also
  sets the pandas dtype the tables use;
- ``description``: what one value is, in a sentence;
- ``unit``: the unit as a UCUM code (https://ucum.org), such as ``kg``,
  ``kcal`` or ``h``; empty when the column has no unit;
- ``codes``: identifiers from recognised vocabularies, where one fits:
  INFOODS tagnames (FAO/UN food component identifiers), USDA FoodData
  Central nutrient ids and numbers, and LOINC codes.

The export (:meth:`ippo.IppoData.export`) writes it out as
``codebook.csv`` and inside ``datapackage.json``, so the files explain
themselves without this package. A test checks that every column of
every table is described here, so a new column cannot be exported
without a description.

Only codes checked against their official source are given. Where none
could be confirmed the code is left out, never guessed. Sources:

- INFOODS tagnames: https://www.fao.org/infoods/infoods/standards-guidelines/food-component-identifiers-tagnames/en/
- USDA FoodData Central: https://fdc.nal.usda.gov (nutrient ``id`` and
  legacy ``number``, as in the FoodData Central API)
- LOINC: https://loinc.org (body weight and daily step count, as used by
  the HL7 FHIR vital signs and mobile health guides)
- UCUM: https://ucum.org/ucum
"""

import re
from dataclasses import dataclass, field

import pandas as pd


@dataclass(frozen=True)
class Column:
    """One column: its name, type, meaning, unit and standard codes."""

    name: str
    type: str
    description: str
    unit: str = ""
    codes: dict = field(default_factory=dict)


@dataclass(frozen=True)
class Nutrient:
    """A nutrient field (see "Nutrients" in docs/data-format.md)."""

    label: str
    unit: str
    infoods: str = ""
    fdc_id: int | None = None
    fdc_number: str = ""
    note: str = ""

    def codes(self):
        """The nutrient's standard codes, leaving out those not known."""
        codes = {}
        if self.infoods:
            codes["infoods"] = self.infoods
        if self.fdc_id is not None:
            codes["usda_fdc_id"] = self.fdc_id
            codes["usda_fdc_number"] = self.fdc_number
        return codes


#: Every nutrient field Ippo names, with its unit (UCUM) and codes.
#: Field names follow the readable style of Open Food Facts (``proteins``,
#: ``fiber``) with the unit at the end; the codes say exactly which
#: component each one is.
NUTRIENTS = {
    "energy_kcal": Nutrient("Energy", "kcal", "ENERC", 1008, "208", "INFOODS ENERC expressed in kcal."),
    "proteins_g": Nutrient("Protein", "g", "PROCNT", 1003, "203"),
    "carbohydrates_g": Nutrient("Carbohydrate, by difference", "g", "CHOCDF", 1005, "205"),
    "sugars_g": Nutrient("Sugars, total", "g", "SUGAR", 2000, "269"),
    "added_sugars_g": Nutrient("Added sugars", "g", note="No standard code confirmed."),
    "fiber_g": Nutrient("Dietary fibre, total", "g", "FIBTG", 1079, "291"),
    "fat_g": Nutrient("Fat, total", "g", "FAT", 1004, "204"),
    "saturated_fat_g": Nutrient("Saturated fatty acids, total", "g", "FASAT", 1258, "606"),
    "monounsaturated_fat_g": Nutrient("Monounsaturated fatty acids, total", "g", "FAMS", 1292, "645"),
    "polyunsaturated_fat_g": Nutrient("Polyunsaturated fatty acids, total", "g", "FAPU", 1293, "646"),
    "trans_fat_g": Nutrient("Trans fatty acids, total", "g", "FATRN", 1257, "605"),
    "cholesterol_mg": Nutrient("Cholesterol", "mg", "CHOLE", 1253, "601"),
    "salt_g": Nutrient(
        "Salt",
        "g",
        "NACL",
        note="2.5 × sodium; worked out from sodium_mg when an entry gave only sodium. INFOODS NACL is in mg.",
    ),
    "sodium_mg": Nutrient(
        "Sodium",
        "mg",
        "NA",
        1093,
        "307",
        note="Worked out from salt_g (salt / 2.5) when an entry gave only salt.",
    ),
    "potassium_mg": Nutrient("Potassium", "mg", "K", 1092, "306"),
    "calcium_mg": Nutrient("Calcium", "mg", "CA", 1087, "301"),
    "iron_mg": Nutrient("Iron", "mg", "FE", 1089, "303"),
    "magnesium_mg": Nutrient("Magnesium", "mg", "MG", 1090, "304"),
    "zinc_mg": Nutrient("Zinc", "mg", "ZN", 1095, "309"),
    "phosphorus_mg": Nutrient("Phosphorus", "mg", "P", 1091, "305"),
    "vitamin_a_ug": Nutrient(
        "Vitamin A",
        "ug",
        fdc_id=1106,
        fdc_number="320",
        note="As on labels; USDA 1106 is retinol activity equivalents (RAE).",
    ),
    "vitamin_c_mg": Nutrient("Vitamin C", "mg", "VITC", 1162, "401"),
    "vitamin_d_ug": Nutrient("Vitamin D (D2 + D3)", "ug", "VITD", 1114, "328"),
    "vitamin_e_mg": Nutrient(
        "Vitamin E",
        "mg",
        "TOCPHA",
        1109,
        "323",
        note="As on labels; the codes are alpha-tocopherol.",
    ),
    "vitamin_k_ug": Nutrient(
        "Vitamin K",
        "ug",
        "VITK",
        1185,
        "430",
        note="USDA 1185 is phylloquinone (K1) only; INFOODS VITK is K1 + K2.",
    ),
    "thiamin_mg": Nutrient("Thiamin", "mg", "THIA", 1165, "404"),
    "riboflavin_mg": Nutrient("Riboflavin", "mg", "RIBF", 1166, "405"),
    "niacin_mg": Nutrient("Niacin (preformed)", "mg", "NIA", 1167, "406"),
    "vitamin_b6_mg": Nutrient("Vitamin B6", "mg", "VITB6A", 1175, "415"),
    "folate_ug": Nutrient(
        "Folate",
        "ug",
        "FOLDFE",
        1190,
        "435",
        note="As on labels, usually dietary folate equivalents; total folate is INFOODS FOL, USDA 1177.",
    ),
    "vitamin_b12_ug": Nutrient("Vitamin B12", "ug", "VITB12", 1178, "418"),
}

#: A nutrient field name: words joined by ``_``, ending in a unit.
NUTRIENT_NAME = re.compile(r"^[a-z][a-z0-9_]*_(g|mg|ug|kcal)$")

#: The UCUM code of each nutrient name ending.
_NUTRIENT_UNITS = {"g": "g", "mg": "mg", "ug": "ug", "kcal": "kcal"}

#: LOINC codes confirmed for the columns they describe.
_WEIGHT_CODES = {"loinc": "29463-7"}
_STEPS_CODES = {"loinc": "41950-7"}

# Columns that mean the same in every table that has them.
_RECORDED = Column("recorded_utc", "datetime", "When the row's latest event was written, in UTC.")
_DATE = Column(
    "date", "date", "The day the row is about, as lived (a day runs until 05:00 the next morning)."
)
_DELETED = Column(
    "deleted", "boolean", "True if deleted in the app. Kept so ids in other tables still resolve."
)
_NOTE = Column("note", "string", "A note typed by the user.")


def _columns(*columns):
    return {column.name: column for column in columns}


#: The named columns of each table. Nutrient columns and the habit
#: columns of ``habit_days`` follow patterns (see :func:`describe`).
TABLES = {
    "habits": _columns(
        Column("habit_id", "string", "The habit's id (UUIDv7); habit_entries refer to it."),
        Column("name", "string", "The habit's latest name."),
        Column("value_type", "string", "What is recorded each day: yes_no, number, duration or time_of_day."),
        Column("unit", "string", "For number habits, the user's unit label, such as pages. Only a label."),
        Column("description", "string", "The user's description."),
        Column("color", "string", "Display colour, #RRGGBB."),
        Column("times", "integer", "Frequency: done this many times ..."),
        Column("per_days", "integer", "... in this many days (1 per 1 is daily)."),
        Column("archived", "boolean", "True if hidden from the app without being deleted."),
        _DELETED,
        _RECORDED,
    ),
    "habit_entries": _columns(
        _DATE,
        Column("habit_id", "string", "The habit (see habits)."),
        Column("habit", "string", "The habit's latest name."),
        Column(
            "value", "any", "The value: true/false for yes_no habits (false is a real no, not a missing day)."
        ),
        Column("skipped", "boolean", "True if skipped on purpose (a rest day)."),
        _NOTE,
        _RECORDED,
    ),
    "habit_days": _columns(_DATE),
    "foods": _columns(
        Column("food_id", "string", "The food's id (UUIDv7); food_entries refer to it."),
        Column("name", "string", "The food's latest name."),
        Column(
            "measured_in",
            "string",
            "g (grams) or ml (millilitres; UCUM mL); nutrient columns are per 100 of these.",
        ),
        Column("serving_unit", "string", "The label's name for one piece, such as slices."),
        Column("serving_count", "number", "How many pieces make one serving."),
        Column("serving_amount", "number", "How much one serving is, in measured_in units."),
        Column("ingredients", "string", "The ingredients as written on the label."),
        _DELETED,
        _RECORDED,
    ),
    "food_entries": _columns(
        Column("entry_id", "string", "The entry's id (UUIDv7)."),
        _DATE,
        Column("time", "string", "Local clock time eaten, HH:MM; empty if not given."),
        Column("name", "string", "The food's name when eaten."),
        Column("food_id", "string", "The food (see foods); empty for a quick entry."),
        Column("quick", "boolean", "True for a quick entry: a name and nutrients typed directly."),
        Column("amount", "number", "How much was eaten, in measured_in units."),
        Column("measured_in", "string", "g or ml (millilitres; UCUM mL)."),
        Column("unit_count", "number", "How many pieces, when entered in the food's serving unit."),
        Column("unit_name", "string", "The name of those pieces."),
        _NOTE,
        _RECORDED,
    ),
    "food_days": _columns(
        Column("food_entries", "integer", "How many food entries the day has."),
        Column(
            "diary_complete",
            "boolean",
            "The user's own mark: True if everything eaten that day is logged, False if not; "
            "empty if never marked. Use it to tell complete days from partly logged ones.",
        ),
    ),
    "exercises": _columns(
        Column("exercise_id", "string", "The exercise's id (UUIDv7); sets refer to it."),
        Column("name", "string", "The exercise's latest name."),
        Column("measured_in", "string", "reps or seconds."),
        Column("description", "string", "The user's description."),
        _DELETED,
        _RECORDED,
    ),
    "sets": _columns(
        Column("set_id", "string", "The set's id (UUIDv7)."),
        _DATE,
        Column("exercise_id", "string", "The exercise (see exercises)."),
        Column("exercise", "string", "The exercise's latest name."),
        Column("set_number", "integer", "1 for the day's first set of this exercise, and so on."),
        Column("value", "integer", "Reps done, or seconds held: see unit."),
        Column("unit", "string", "The unit of value: reps or seconds (UCUM {reps} or s)."),
        Column("weight_kg", "number", "Added weight; empty means body weight only.", "kg"),
        Column("reps_in_reserve", "integer", "How many more reps could have been done."),
        _NOTE,
        _RECORDED,
    ),
    "exercise_days": _columns(
        _DATE,
        Column("exercise_id", "string", "The exercise (see exercises)."),
        Column("exercise", "string", "The exercise's latest name."),
        Column("unit", "string", "The unit of total and best: reps or seconds (UCUM {reps} or s)."),
        Column("sets", "integer", "How many sets."),
        Column("total", "integer", "All reps (or seconds) of the day added up."),
        Column("best", "integer", "The most reps (or seconds) in one set."),
    ),
    "steps": _columns(
        _DATE,
        Column(
            "steps",
            "integer",
            "Steps walked that day, as typed in from a watch or phone.",
            "{steps}/d",
            _STEPS_CODES,
        ),
        _RECORDED,
    ),
    "sleep_days": _columns(
        Column("woke_up_utc", "datetime", "When the day began: waking up, in UTC."),
        Column("woke_up_local", "datetime", "The same moment on the local clock where the user was."),
        Column("woke_up_h", "number", "Local wake-up time as hours after midnight (7.5 is 07:30).", "h"),
        Column("went_to_bed_utc", "datetime", "When the day ended: going to bed, in UTC."),
        Column("went_to_bed_local", "datetime", "The same moment on the local clock."),
        Column(
            "went_to_bed_h",
            "number",
            "Local bedtime as hours after the day's midnight (25.0 is 01:00 next day).",
            "h",
        ),
        Column("sleep_before_h", "number", "Hours from the previous day's bedtime to this wake-up.", "h"),
        Column(
            "time_zone_changed", "boolean", "True if that night's bedtime and wake-up had different offsets."
        ),
        Column("awake_h", "number", "Hours from wake-up to bedtime.", "h"),
        Column("naps", "integer", "How many naps."),
        Column("nap_h", "number", "Hours napped in total.", "h"),
    ),
    "naps": _columns(
        Column("nap_id", "string", "The nap's id (UUIDv7)."),
        _DATE,
        Column("started_utc", "datetime", "When the nap started, in UTC."),
        Column("started_local", "datetime", "The same moment on the local clock."),
        Column("ended_utc", "datetime", "When the nap ended, in UTC."),
        Column("ended_local", "datetime", "The same moment on the local clock."),
        Column("hours", "number", "How long the nap was.", "h"),
    ),
    "weights": _columns(
        _DATE,
        Column("weight_kg", "number", "Body weight.", "kg", _WEIGHT_CODES),
        _RECORDED,
    ),
    "profile": _columns(
        Column("sex", "string", "female or male, as given for the BMR formula."),
        Column("birth_year", "integer", "Year of birth."),
        Column("height_cm", "number", "Body height.", "cm"),
    ),
    "energy_targets": _columns(
        Column("date", "date", "The first day this limit applies to."),
        Column(
            "energy_kcal",
            "number",
            "The daily energy limit set by the user; empty means the limit was removed.",
            "kcal",
        ),
        _RECORDED,
    ),
    "logging_activity": _columns(
        Column("module", "string", "The module the events belong to: habits, food, exercise, sleep, body."),
        Column("events", "integer", "How many events were written about this day in this module "
               "(entries, and changes or deletions of them)."),
        Column("first_recorded_utc", "datetime", "When the first of them was written, in UTC."),
        Column("last_recorded_utc", "datetime", "When the last of them was written, in UTC."),
        Column("first_logged_days_after", "integer", "How many days after the day the first event was "
               "written, by the day as lived (0: the same day). Logging from memory is less reliable."),
    ),
    "nutrient_targets": _columns(
        Column("date", "date", "The first day this goal applies to."),
        Column("nutrient", "string", "The nutrient's field name, such as fat_g (see the nutrient columns)."),
        Column(
            "amount",
            "number",
            "The user's own amount a day, in the nutrient's unit; empty means the goal was "
            "removed and the reference amount applies again.",
        ),
        Column("kind", "string", "at_most (a limit, such as fat) or at_least (a minimum, such as protein)."),
        _RECORDED,
    ),
    "daily": _columns(
        Column("any_logged", "boolean", "Whether anything at all was logged about this day."),
        Column("habits_logged", "boolean", "Whether any habit was marked (done or not) on this day."),
        Column("food_logged", "boolean", "Whether any food was logged on this day. Whether all of it was "
               "cannot be known."),
        Column("exercise_logged", "boolean", "Whether any exercise set was logged on this day (steps are "
               "counted in steps)."),
        Column("sleep_logged", "boolean", "Whether a wake-up, bedtime or nap was logged for this day."),
        Column("habits_done", "integer", "Yes/no habits marked done; empty if no habit was marked."),
        Column("habits_marked", "integer", "Habits with any value recorded; empty if none."),
        Column("woke_up_h", "number", "See sleep_days.", "h"),
        Column("went_to_bed_h", "number", "See sleep_days.", "h"),
        Column("sleep_before_h", "number", "See sleep_days.", "h"),
        Column("time_zone_changed", "boolean", "See sleep_days."),
        Column("awake_h", "number", "See sleep_days.", "h"),
        Column("nap_h", "number", "See sleep_days.", "h"),
        Column("exercise_sets", "integer", "How many exercise sets were logged; empty if none (a rest "
               "day and a day not logged look the same)."),
        Column("steps", "integer", "Steps walked.", "{steps}/d", _STEPS_CODES),
        Column("weight_kg", "number", "Body weight logged that day.", "kg", _WEIGHT_CODES),
        Column("energy_target_kcal", "number", "The daily energy limit that applied.", "kcal"),
    ),
    "devices": _columns(
        Column("device_id", "string", "The device's id (UUIDv7): one per install of the app."),
        Column("device_name", "string", "The device's latest name, chosen by the user."),
        Column("events", "integer", "How many events it wrote."),
        Column("first_seen_utc", "datetime", "Its first event, in UTC."),
        Column("last_seen_utc", "datetime", "Its latest event, in UTC."),
    ),
    "events": _columns(
        Column("format_version", "integer", "The version of docs/data-format.md the event follows."),
        Column("id", "string", "The event's unique id (UUIDv7)."),
        Column("recorded_at", "string", "When it was written: RFC 3339 with the local offset."),
        Column("device_id", "string", "The device that wrote it."),
        Column("device_name", "string", "That device's name at the time."),
        Column(
            "app_version",
            "string",
            "The version of the app that wrote it; empty for events written before this was recorded.",
        ),
        Column(
            "time_zone",
            "string",
            "The IANA time zone the device was set to, such as Europe/Paris; empty if not known.",
        ),
        Column("module", "string", "The module: habits, food, exercise, sleep, body, ..."),
        Column("type", "string", "What happened, such as habit_created."),
        Column("data", "string", "The event's details as JSON (see docs/data-format.md)."),
        Column("file", "string", "The file it was read from."),
    ),
}
# daily repeats food_days' columns (except per-food details).
TABLES["daily"] = {**_columns(*TABLES["food_days"].values()), **TABLES["daily"]}


def describe(table, column):
    """The :class:`Column` describing ``column`` of ``table``, or None if
    the codebook does not know it.

    Besides the named columns, it knows the patterns: nutrient columns
    (``proteins_g``), their ``_complete`` flags, the foods table's
    ``_per_100`` values, and in ``habit_days`` one column per habit.
    """
    named = TABLES.get(table, {}).get(column)
    if named is not None:
        return named
    if column == "date":
        return _DATE
    if table == "habit_days":
        return Column(
            column, "any", f"The value recorded for the habit named {column!r} (see habit_entries)."
        )
    if table == "foods" and column.endswith("_per_100"):
        nutrient = describe_nutrient(column.removesuffix("_per_100"))
        if nutrient is not None:
            return Column(
                column,
                "number",
                f"{nutrient.description} per 100 g or 100 ml (see measured_in).",
                nutrient.unit,
                nutrient.codes,
            )
    if table in ("food_entries", "food_days", "daily"):
        if column.endswith("_complete"):
            nutrient = describe_nutrient(column.removesuffix("_complete"))
            if nutrient is not None:
                return Column(
                    column,
                    "boolean",
                    f"True if every entry that day gave {nutrient.name}, so its total is the "
                    "whole of what was logged; False means some entries did not say.",
                )
        nutrient = describe_nutrient(column)
        if nutrient is not None:
            if table == "food_entries":
                return Column(
                    column, "number", f"{nutrient.description} in this entry.", nutrient.unit, nutrient.codes
                )
            return Column(
                column,
                "number",
                f"{nutrient.description} eaten that day: the sum of the entries that gave it.",
                nutrient.unit,
                nutrient.codes,
            )
    return None


def describe_nutrient(name):
    """A :class:`Column` for the nutrient field ``name``, or None if it is
    not a nutrient name. Nutrients not in :data:`NUTRIENTS` still get
    their unit from the name's ending."""
    if not NUTRIENT_NAME.match(name):
        return None
    known = NUTRIENTS.get(name)
    if known is None:
        unit = _NUTRIENT_UNITS[name.rsplit("_", 1)[1]]
        label = name.rsplit("_", 1)[0].replace("_", " ").capitalize()
        return Column(name, "number", label, unit)
    description = known.label + (f" ({known.note})" if known.note else "")
    return Column(name, "number", description, known.unit, known.codes())


#: The pandas dtype each Frictionless type is given, so a column's dtype
#: never depends on whether it happens to hold values (an empty note
#: column is still text, not numbers).
_DTYPES = {"string": "string", "integer": "Int64", "number": "float64", "boolean": "boolean"}


def apply_types(table, frame):
    """Returns ``frame`` with every column it describes in the pandas
    dtype of its codebook type. Dates and moments are left as they are;
    ``any`` columns too."""
    frame = frame.copy()
    for name in frame.columns:
        column = describe(table, name)
        dtype = _DTYPES.get(column.type) if column else None
        if dtype is None:
            continue
        values = frame[name]
        if dtype == "string":
            # Missing stays missing, rather than the text "nan".
            frame[name] = values.astype("object").where(values.notna(), None).astype("string")
        elif dtype == "Int64":
            frame[name] = pd.to_numeric(values).astype("Int64")
        else:
            frame[name] = values.astype(dtype)
    return frame
