# SPDX-License-Identifier: GPL-3.0-or-later
"""One row per day, with a summary of every module side by side.

This is the table most analyses start from: plot a column over time,
take rolling means, or compare columns ("do I eat more after short
nights?").
"""

import pandas as pd

from .body import energy_target_on, energy_targets, weights
from .exercise import sets, steps
from .food import food_days, food_entries
from .habits import habit_entries
from .sleep import sleep_days

_SLEEP_COLUMNS = ["woke_up_h", "went_to_bed_h", "sleep_before_h", "time_zone_changed", "awake_h", "nap_h"]


def daily(events):
    """One row per day, indexed by date, from the first day with any data
    to the last. Days without data are included, with empty values, so
    gaps are visible and rolling means line up with the calendar.

    Columns:

    - ``any_logged``, ``habits_logged``, ``food_logged``,
      ``exercise_logged``, ``sleep_logged``: whether anything at all was
      logged about that day (in any module, or in that one). A day with
      nothing logged is unknown, never "none": see "Missing data" in
      ``python/README.md``.
    - ``habits_done``: yes/no habits marked done;
      ``habits_marked``: habits with any value that day.
    - ``food_entries`` and every column of :func:`ippo.food.food_days`
      (nutrient totals, and whether each total is complete).
    - ``woke_up_h``, ``went_to_bed_h``, ``sleep_before_h``,
      ``time_zone_changed``, ``awake_h``, ``nap_h`` from
      :func:`ippo.sleep.sleep_days`.
    - ``exercise_sets``: how many sets were logged; ``steps``: the
      steps walked.
    - ``weight_kg``: the weight logged that day; ``energy_target_kcal``:
      the daily energy limit that applied.

    Counts (``habits_done``, ``habits_marked``, ``food_entries``,
    ``exercise_sets``) are empty, not 0, on days nothing was logged in
    their module, and so are measurements (nutrients, sleep times,
    steps, weight): "not logged" is not the same as zero. Whether a
    logged day is complete (every meal, every set) cannot be known from
    the data; that is for the analysis to judge.
    """
    entries = habit_entries(events)
    food = food_days(events)
    sleep = sleep_days(events)[_SLEEP_COLUMNS]
    exercise = sets(events)
    walked = steps(events)
    weighed = weights(events)

    known_days = [
        days
        for days in (
            entries["date"],
            food.index.to_series(),
            sleep.index.to_series(),
            exercise["date"],
            walked["date"],
            weighed["date"],
        )
        if not days.empty
    ]
    if not known_days:
        return pd.DataFrame(index=pd.DatetimeIndex([], name="date"))
    known_days = pd.concat(known_days)
    days = pd.date_range(known_days.min(), known_days.max(), name="date")

    result = pd.DataFrame(index=days)
    # Whether anything was logged about each day, module by module.
    eaten = food_entries(events)["date"]
    slept = sleep.index.to_series()
    result["habits_logged"] = days.isin(entries["date"])
    result["food_logged"] = days.isin(eaten)
    result["exercise_logged"] = days.isin(exercise["date"])
    result["sleep_logged"] = days.isin(slept)
    result["any_logged"] = days.isin(known_days)
    habits = entries.groupby("date")
    result["habits_done"] = habits["value"].apply(lambda values: (values == True).sum())  # noqa: E712
    result["habits_marked"] = habits.size()
    result = result.join(food).join(sleep)
    result["exercise_sets"] = exercise.groupby("date").size()
    result["steps"] = walked.set_index("date")["steps"].astype("Int64")
    result["weight_kg"] = weighed.set_index("date")["weight_kg"]
    result["energy_target_kcal"] = energy_target_on(energy_targets(events), days)

    # Counts stay empty on days their module has nothing: a day nobody
    # logged is not a day of none.
    for count in ("habits_done", "habits_marked", "food_entries", "exercise_sets"):
        result[count] = result[count].astype("Int64")
    for flag in [column for column in result.columns if column.endswith("_complete")]:
        result[flag] = result[flag].astype("boolean")
    first = ["any_logged", "habits_logged", "food_logged", "exercise_logged", "sleep_logged"]
    return result[first + [column for column in result.columns if column not in first]]
