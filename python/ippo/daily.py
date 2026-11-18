# SPDX-License-Identifier: GPL-3.0-or-later
"""One row per day, with a summary of every module side by side.

This is the table most analyses start from: plot a column over time,
take rolling means, or compare columns ("do I eat more after short
nights?").
"""

import pandas as pd

from .exercise import sets
from .food import food_days
from .habits import habit_entries
from .sleep import sleep_days

_SLEEP_COLUMNS = ["woke_up_h", "went_to_bed_h", "sleep_before_h", "time_zone_changed", "awake_h", "nap_h"]


def daily(events):
    """One row per day, indexed by date, from the first day with any data
    to the last. Days without data are included, with empty values, so
    gaps are visible and rolling means line up with the calendar.

    Columns:

    - ``habits_done``: yes/no habits marked done;
      ``habits_logged``: habits with any value that day.
    - ``food_entries`` and every column of :func:`ippo.food.food_days`
      (nutrient totals, and whether each total is complete).
    - ``woke_up_h``, ``went_to_bed_h``, ``sleep_before_h``,
      ``time_zone_changed``, ``awake_h``, ``nap_h`` from
      :func:`ippo.sleep.sleep_days`.
    - ``exercise_sets``: how many sets were logged.

    Counts are 0 on days without entries. Measurements (nutrients, sleep
    times) are empty, because "not logged" is not the same as zero.
    """
    entries = habit_entries(events)
    food = food_days(events)
    sleep = sleep_days(events)[_SLEEP_COLUMNS]
    exercise = sets(events)

    known_days = [
        days
        for days in (entries["date"], food.index.to_series(), sleep.index.to_series(), exercise["date"])
        if not days.empty
    ]
    if not known_days:
        return pd.DataFrame(index=pd.DatetimeIndex([], name="date"))
    known_days = pd.concat(known_days)
    days = pd.date_range(known_days.min(), known_days.max(), name="date")

    result = pd.DataFrame(index=days)
    habits = entries.groupby("date")
    result["habits_done"] = habits["value"].apply(lambda values: (values == True).sum())  # noqa: E712
    result["habits_logged"] = habits.size()
    result = result.join(food).join(sleep)
    result["exercise_sets"] = exercise.groupby("date").size()

    for count in ("habits_done", "habits_logged", "food_entries", "exercise_sets"):
        result[count] = result[count].fillna(0).astype(int)
    for flag in [column for column in result.columns if column.endswith("_complete")]:
        result[flag] = result[flag].astype("boolean")
    return result
