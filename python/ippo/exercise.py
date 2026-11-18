# SPDX-License-Identifier: GPL-3.0-or-later
"""Tables for the exercise module ("Module: exercise" in the data format)."""

import pandas as pd

from .things import as_dates, collect_things, table


def exercises(events):
    """One row per exercise, including deleted ones.

    Columns: ``exercise_id``, ``name``, ``measured_in`` (``"reps"`` or
    ``"seconds"``), ``description``, ``deleted``, ``recorded_utc``.
    """
    rows = collect_things(events, "exercise", "exercise_created", "exercise")
    return table(
        rows, ["id", "name", "measured_in", "description", "deleted", "recorded_utc"]
    ).rename(columns={"id": "exercise_id"})


def sets(events):
    """One row per set. Deleted sets, and sets of deleted exercises, are
    left out, as in the app.

    In the files, a set stores ``reps`` or ``seconds`` depending on the
    exercise. Here both become ``value``, with the unit in ``unit``, so
    every exercise fits in one column.

    Columns: ``set_id``, ``date``, ``exercise_id``, ``exercise`` (its
    current name), ``set_number``, ``value``, ``unit``, ``weight_kg``,
    ``reps_in_reserve``, ``note``, ``recorded_utc``.
    """
    definitions = exercises(events)
    live = definitions[~definitions["deleted"]].set_index("exercise_id")

    rows = []
    for item in collect_things(events, "exercise", "set_recorded", "set"):
        exercise_id = item.get("exercise_id")
        if item["deleted"] or exercise_id not in live.index:
            continue
        rows.append({
            "set_id": item["id"],
            "date": item.get("date"),
            "exercise_id": exercise_id,
            "exercise": live.at[exercise_id, "name"],
            "set_number": item.get("set_number"),
            "value": item.get("reps", item.get("seconds")),
            "unit": live.at[exercise_id, "measured_in"],
            "weight_kg": item.get("weight_kg"),
            "reps_in_reserve": item.get("reps_in_reserve"),
            "note": item.get("note"),
            "recorded_utc": item["recorded_utc"],
        })
    columns = ["set_id", "date", "exercise_id", "exercise", "set_number", "value",
               "unit", "weight_kg", "reps_in_reserve", "note", "recorded_utc"]
    result = table(rows, columns)
    result["date"] = as_dates(result["date"])
    result["value"] = pd.to_numeric(result["value"], errors="coerce")
    result = result.dropna(subset=["date", "value"])
    return result.sort_values(["date", "recorded_utc"]).reset_index(drop=True)


def exercise_days(events):
    """One row per exercise per day it was done.

    Columns: ``date``, ``exercise_id``, ``exercise``, ``unit``, ``sets``
    (how many), ``total`` (all reps or seconds added up), ``best`` (the
    best single set). ``best`` is usually the clearest sign of progress.
    """
    grouped = sets(events).groupby(["date", "exercise_id", "exercise", "unit"])
    result = grouped["value"].agg(sets="count", total="sum", best="max")
    return result.reset_index()
