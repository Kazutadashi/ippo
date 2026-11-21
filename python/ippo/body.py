# SPDX-License-Identifier: GPL-3.0-or-later
"""Tables for the body module ("Module: body" in the data format)."""

import pandas as pd

from .things import as_dates, collect_things, table


def weights(events):
    """One row per day with a weight logged. Deleted weighings are left
    out; if a day has two (from two devices), the one recorded last
    counts, as in the app.

    Columns: ``date``, ``weight_kg``, ``recorded_utc``.
    """
    rows = [
        {"date": item.get("date"), "weight_kg": item.get("weight_kg"), "recorded_utc": item["recorded_utc"]}
        for item in collect_things(events, "body", "weight_recorded", "weight")
        if not item["deleted"]
    ]
    result = table(rows, ["date", "weight_kg", "recorded_utc"])
    result["date"] = as_dates(result["date"])
    result["weight_kg"] = pd.to_numeric(result["weight_kg"], errors="coerce")
    result = result.dropna(subset=["date", "weight_kg"]).sort_values(["date", "recorded_utc"])
    return result.drop_duplicates("date", keep="last").reset_index(drop=True)


def profile(events):
    """The latest sex, year of birth and height, as one row (each field
    of the latest ``profile_recorded`` event that has it), or no rows if
    none was recorded.

    Columns: ``sex``, ``birth_year``, ``height_cm``.
    """
    latest = {}
    of_body = events[(events["module"] == "body") & (events["type"] == "profile_recorded")]
    for event in of_body.itertuples(index=False):
        for field in ("sex", "birth_year", "height_cm"):
            if event.data.get(field) is not None:
                latest[field] = event.data[field]
    return pd.DataFrame([latest] if latest else [], columns=["sex", "birth_year", "height_cm"])


def energy_targets(events):
    """One row per daily energy limit set, in the order recorded.

    Columns: ``date`` (the first day it applies to), ``energy_kcal``
    (empty for "no limit"), ``recorded_utc``.
    """
    of_body = events[(events["module"] == "body") & (events["type"] == "energy_target_recorded")]
    rows = [
        {
            "date": event.data.get("date"),
            "energy_kcal": event.data.get("energy_kcal"),
            "recorded_utc": event.recorded_utc,
        }
        for event in of_body.itertuples(index=False)
    ]
    result = table(rows, ["date", "energy_kcal", "recorded_utc"])
    result["date"] = as_dates(result["date"])
    result["energy_kcal"] = pd.to_numeric(result["energy_kcal"], errors="coerce")
    return result.dropna(subset=["date"]).reset_index(drop=True)


def nutrient_targets(events):
    """One row per daily nutrient goal set, in the order recorded.

    A goal replaces the reference amount for its nutrient from ``date``
    on, until the next goal for that nutrient.

    Columns: ``date`` (the first day it applies to), ``nutrient`` (a
    field name such as ``fat_g``), ``amount`` (in the nutrient's unit;
    empty when the goal was removed and the reference applies again),
    ``kind`` (``at_most`` or ``at_least``), ``recorded_utc``.
    """
    of_body = events[(events["module"] == "body") & (events["type"] == "nutrient_target_recorded")]
    rows = [
        {
            "date": event.data.get("date"),
            "nutrient": event.data.get("nutrient"),
            "amount": event.data.get("amount"),
            "kind": event.data.get("kind"),
            "recorded_utc": event.recorded_utc,
        }
        for event in of_body.itertuples(index=False)
    ]
    result = table(rows, ["date", "nutrient", "amount", "kind", "recorded_utc"])
    result["date"] = as_dates(result["date"])
    result["amount"] = pd.to_numeric(result["amount"], errors="coerce")
    return result.dropna(subset=["date", "nutrient"]).reset_index(drop=True)


def energy_target_on(targets, days):
    """The limit that applies on each of ``days``: of the limits starting
    on or before a day, the one with the latest start (and of those, the
    one recorded last). Returns a Series indexed by ``days``."""
    ordered = targets.sort_values(["date", "recorded_utc"])
    values = []
    for day in days:
        before = ordered[ordered["date"] <= day]
        values.append(before["energy_kcal"].iloc[-1] if not before.empty else float("nan"))
    return pd.Series(values, index=days, dtype=float)
