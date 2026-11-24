# SPDX-License-Identifier: GPL-3.0-or-later
"""When and how much was logged about each day: the raw material for
studying missing data.

Whether a day's data is complete cannot be known: a day with one meal
logged may be a day of one meal, or a day the rest was not written down.
This table does not guess. It records what can be known, so an analysis
can model logging behaviour itself: how many events were written about
each day and module, when the first and last were written, and how many
days after the day the first one came (logging from memory, days later,
is less reliable than logging as it happens).
"""

import pandas as pd

from .things import as_dates

#: A day lasts until this hour of the next morning, as in the app
#: (``dayStartHour`` in ``lib/core/dates.dart``): an event recorded at
#: 01:00 belongs to the evening before.
DAY_START_HOUR = 5

#: The modules this package knows. Events of others (from a newer app)
#: are left out, as every other table leaves them out.
_MODULES = {"habits", "food", "exercise", "sleep", "body"}

#: Event types that set something from a day on, rather than log the
#: day itself (a calorie limit, a nutrient goal). Left out.
_SETTINGS = {"energy_target_recorded", "nutrient_target_recorded"}


def logging_activity(events):
    """One row per day and module with anything logged about that day.

    An event is "about" a day when it records something for that date
    (``data.date``), or changes or deletes such a record (it then counts
    for the record's day, or for the new day if the change moved it).

    Columns:

    - ``date``, ``module``;
    - ``events``: how many events were written about that day;
    - ``first_recorded_utc``, ``last_recorded_utc``: when the first and
      last of them were written;
    - ``first_logged_days_after``: how many days after the day the first
      event was written, by the day as lived where it was written (0:
      the same day; 1: the next day, and so on).
    """
    day_of = {}
    rows = []
    for event in events.itertuples(index=False):
        if event.type in _SETTINGS or event.module not in _MODULES:
            continue
        data = event.data
        date = data.get("date")
        target = data.get("target_id")
        if isinstance(target, str):
            changes = data.get("changes")
            moved = changes.get("date") if isinstance(changes, dict) else None
            date = moved if isinstance(moved, str) else day_of.get(target)
            if isinstance(moved, str):
                day_of[target] = moved
        elif isinstance(date, str):
            day_of[event.id] = date
        if not isinstance(date, str):
            continue
        rows.append({
            "date": date,
            "module": event.module,
            "recorded_utc": event.recorded_utc,
            "recorded_local": event.recorded_local,
        })

    columns = [
        "date", "module", "events",
        "first_recorded_utc", "last_recorded_utc", "first_logged_days_after",
    ]
    if not rows:
        return pd.DataFrame(columns=columns)
    frame = pd.DataFrame(rows)
    frame["date"] = as_dates(frame["date"])
    frame = frame.dropna(subset=["date"])
    grouped = frame.groupby(["date", "module"])
    result = grouped.agg(
        events=("recorded_utc", "size"),
        first_recorded_utc=("recorded_utc", "min"),
        last_recorded_utc=("recorded_utc", "max"),
        first_recorded_local=("recorded_local", "min"),
    ).reset_index()
    # The day as lived when the first event was written: before 05:00 it
    # is still the evening before.
    lived = (result["first_recorded_local"] - pd.Timedelta(hours=DAY_START_HOUR)).dt.normalize()
    result["first_logged_days_after"] = (lived - result["date"]).dt.days
    return result[columns].sort_values(["date", "module"]).reset_index(drop=True)
