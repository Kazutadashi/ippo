# SPDX-License-Identifier: GPL-3.0-or-later
"""Tables for the food module ("Module: food" in the data format)."""

import re

import pandas as pd

from .things import as_dates, collect_things, table

#: Every nutrient field in the format, in the order used in tables.
NUTRIENTS = [
    "energy_kcal",
    "proteins_g",
    "carbohydrates_g",
    "sugars_g",
    "added_sugars_g",
    "fiber_g",
    "fat_g",
    "saturated_fat_g",
    "monounsaturated_fat_g",
    "polyunsaturated_fat_g",
    "trans_fat_g",
    "cholesterol_mg",
    "salt_g",
    "sodium_mg",
    "potassium_mg",
    "calcium_mg",
    "iron_mg",
    "magnesium_mg",
    "zinc_mg",
    "phosphorus_mg",
    "vitamin_a_ug",
    "vitamin_c_mg",
    "vitamin_d_ug",
    "vitamin_e_mg",
    "vitamin_k_ug",
    "thiamin_mg",
    "riboflavin_mg",
    "niacin_mg",
    "vitamin_b6_mg",
    "folate_ug",
    "vitamin_b12_ug",
]


#: A nutrient field name: words joined by ``_``, ending in its unit.
_NUTRIENT_NAME = re.compile(r"^[a-z][a-z0-9_]*_(g|mg|ug|kcal)$")


def nutrient_columns(nutrient_dicts):
    """The nutrient columns for a table: every field in :data:`NUTRIENTS`,
    then any other nutrient found in ``nutrient_dicts`` (for example
    added by a newer app version), alphabetically. So a nutrient that
    first appears later in the data gets its own column, empty before."""
    found = set()
    for nutrients in nutrient_dicts:
        found.update(key for key in nutrients if _NUTRIENT_NAME.match(key))
    return NUTRIENTS + sorted(found - set(NUTRIENTS))


def foods(events):
    """One row per food in your list, including deleted ones.

    Columns: ``food_id``, ``name``, ``measured_in`` (``"g"`` or
    ``"ml"``), ``serving_unit``, ``serving_count``, ``serving_amount``
    (for example 9 "chips" weigh 28 g), one ``<nutrient>_per_100``
    column per nutrient, ``ingredients`` (as on the label), ``deleted``,
    ``recorded_utc``.
    """
    things = collect_things(events, "food", "food_created", "food")
    nutrients_list = nutrient_columns(_dict(food.get("nutrients_per_100")) for food in things)
    rows = []
    for food in things:
        row = {
            "food_id": food["id"],
            "name": food.get("name"),
            "measured_in": food.get("measured_in"),
            "ingredients": food.get("ingredients"),
            "deleted": food["deleted"],
            "recorded_utc": food["recorded_utc"],
        }
        serving = food.get("serving")
        if isinstance(serving, dict):
            row["serving_unit"] = serving.get("unit")
            row["serving_count"] = _number(serving.get("count"))
            row["serving_amount"] = _number(serving.get("amount"))
        per_100 = _dict(food.get("nutrients_per_100"))
        for nutrient in nutrients_list:
            row[f"{nutrient}_per_100"] = _number(per_100.get(nutrient))
        rows.append(row)
    columns = (
        ["food_id", "name", "measured_in", "serving_unit", "serving_count", "serving_amount"]
        + [f"{nutrient}_per_100" for nutrient in nutrients_list]
        + ["ingredients", "deleted", "recorded_utc"]
    )
    return table(rows, columns)


def food_entries(events):
    """One row per thing eaten. Deleted entries are left out.

    The nutrients are those copied into the entry when it was logged, so
    later changes to a food do not change past days.

    ``salt_g`` and ``sodium_mg`` are one measurement in two forms (salt
    is 2.5 times sodium). Labels give one or the other, so when an entry
    gave only one, the other is worked out here (as the app does), and
    days add up both alike.

    **A missing nutrient means "not known", never zero.** Quick entries
    (``quick`` is ``True``) usually only have energy. Their other
    nutrient columns are empty (NaN).

    Columns: ``entry_id``, ``date``, ``time`` (``"HH:MM"`` or empty),
    ``name``, ``food_id``, ``quick``, ``amount``, ``measured_in``,
    ``unit_count``, ``unit_name``, one column per nutrient (for this
    amount; see :func:`nutrient_columns`), ``note``, ``recorded_utc``.
    """
    things = collect_things(events, "food", "food_entry_recorded", "food_entry")
    nutrients_list = nutrient_columns(_salt_and_sodium(_dict(entry.get("nutrients"))) for entry in things)
    rows = []
    for entry in things:
        if entry["deleted"]:
            continue
        row = {
            "entry_id": entry["id"],
            "date": entry.get("date"),
            "time": entry.get("time"),
            "name": entry.get("name"),
            "food_id": entry.get("food_id"),
            "quick": entry.get("food_id") is None,
            "amount": _number(entry.get("amount")),
            "measured_in": entry.get("measured_in"),
            "unit_count": _number(entry.get("unit_count")),
            "unit_name": entry.get("unit_name"),
            "note": entry.get("note"),
            "recorded_utc": entry["recorded_utc"],
        }
        nutrients = _salt_and_sodium(_dict(entry.get("nutrients")))
        for nutrient in nutrients_list:
            row[nutrient] = _number(nutrients.get(nutrient))
        rows.append(row)
    columns = (
        ["entry_id", "date", "time", "name", "food_id", "quick", "amount",
         "measured_in", "unit_count", "unit_name"]
        + nutrients_list
        + ["note", "recorded_utc"]
    )
    result = table(rows, columns)
    result["date"] = as_dates(result["date"])
    result = result.dropna(subset=["date"])
    return result.sort_values(["date", "time", "recorded_utc"], na_position="last").reset_index(drop=True)


def food_days(events):
    """Totals per day, indexed by date. Only days with entries are listed.

    For each nutrient there are two columns:

    - ``<nutrient>``: the total of the values that are known;
    - ``<nutrient>_complete``: ``True`` if every entry that day had this
      nutrient, so the total is the whole day. ``False`` means at least
      one entry (often a quick entry) did not say, so the real total is
      probably higher.

    Also ``food_entries``: how many entries the day has, and
    ``diary_complete``: the user's own mark that everything eaten that
    day is logged (True), or is not (False); empty if the day was never
    marked. Days marked but without entries are listed too, since a
    complete day with nothing eaten is information.
    """
    entries = food_entries(events)
    grouped = entries.groupby("date")
    result = pd.DataFrame({"food_entries": grouped.size()})
    marks = diary_marks(events)
    result = result.join(marks, how="outer")
    result["food_entries"] = result["food_entries"].fillna(0).astype(int)
    nutrients_list = [column for column in entries.columns if _NUTRIENT_NAME.match(column)]
    for nutrient in nutrients_list:
        # min_count=1: a day where no entry knows the nutrient is empty,
        # not zero.
        result[nutrient] = grouped[nutrient].sum(min_count=1)
        result[f"{nutrient}_complete"] = grouped[nutrient].apply(lambda values: values.notna().all())
    result.index.name = "date"
    columns = ["food_entries", "diary_complete"]
    return result[columns + [column for column in result.columns if column not in columns]]


def diary_marks(events):
    """The ``diary_complete`` mark of each day ever marked, indexed by
    date: the latest ``diary_day_marked`` event for that date wins."""
    marks = {}
    rows = events[(events["module"] == "food") & (events["type"] == "diary_day_marked")]
    for data in rows["data"]:  # oldest first, so later marks win
        date = data.get("date")
        complete = data.get("complete")
        if isinstance(date, str) and isinstance(complete, bool):
            marks[date] = complete
    result = pd.DataFrame(
        {"diary_complete": pd.array(list(marks.values()), dtype="boolean")},
        index=as_dates(pd.Series(list(marks.keys()), dtype="object")),
    )
    result.index.name = "date"
    return result[result.index.notna()]


#: How much salt (sodium chloride) holds a unit of sodium, as EU labelling
#: law counts it (Regulation (EU) No 1169/2011, Annex I, point 11).
SALT_PER_SODIUM = 2.5


def _salt_and_sodium(nutrients):
    """``nutrients`` with salt and sodium both present when either is."""
    salt = _number(nutrients.get("salt_g"))
    sodium = _number(nutrients.get("sodium_mg"))
    if pd.isna(salt) == pd.isna(sodium):
        return nutrients
    filled = dict(nutrients)
    if pd.isna(salt):
        filled["salt_g"] = round(sodium * SALT_PER_SODIUM / 1000, 1)
    else:
        filled["sodium_mg"] = round(salt * 1000 / SALT_PER_SODIUM)
    return filled


def _number(value):
    """Returns ``value`` if it is a number, otherwise NaN."""
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return value
    return float("nan")


def _dict(value):
    """Returns ``value`` if it is a JSON object, otherwise an empty one."""
    return value if isinstance(value, dict) else {}
