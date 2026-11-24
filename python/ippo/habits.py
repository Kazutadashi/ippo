# SPDX-License-Identifier: GPL-3.0-or-later
"""Tables for the habits module ("Module: habits" in the data format)."""

import pandas as pd

from .things import as_dates, collect_things, latest_per, table


def habits(events):
    """One row per habit, including deleted ones (see ``deleted``).

    Columns: ``habit_id``, ``name``, ``value_type`` (``"yes_no"``,
    ``"number"``, ...), ``unit``, ``description``, ``color``
    (``"#RRGGBB"``, or empty for the app's accent color), ``times`` and
    ``per_days`` (how often: ``times`` in every ``per_days`` days; 1 and
    1 for every day), ``archived``, ``deleted``, ``recorded_utc`` (when it
    was created).
    """
    rows = collect_things(events, "habits", "habit_created", "habit")
    for row in rows:
        row["times"], row["per_days"] = _frequency(row.get("frequency"))
    columns = [
        "id", "name", "value_type", "unit", "description", "color",
        "times", "per_days", "archived", "deleted", "recorded_utc",
    ]
    result = table(rows, columns).rename(columns={"id": "habit_id"})
    result["archived"] = result["archived"].eq(True)
    return result


def _frequency(value):
    """How often a habit applies, as ``(times, per_days)``. Anything that
    is not a sensible frequency means every day, ``(1, 1)``, as in the
    app (``HabitFrequency.fromJson``)."""
    if not isinstance(value, dict):
        return 1, 1
    times, per_days = value.get("times"), value.get("per_days")
    is_whole = all(isinstance(number, int) and not isinstance(number, bool) for number in (times, per_days))
    if not is_whole or times < 1 or per_days < 1 or times > per_days or per_days > 365:
        return 1, 1
    return times, per_days


def habit_entries(events):
    """One row per habit per day that has a value.

    If several values were recorded for the same habit and day, only the
    latest counts. Deleted entries, and the entries of deleted habits,
    are left out, just as the app does.

    Three states matter here. ``value`` ``True`` means done, ``False``
    means you said you did not do it, and a day with no row means
    nothing was recorded.

    Columns: ``date``, ``habit_id``, ``habit`` (its current name),
    ``value``, ``skipped``, ``note``, ``recorded_utc`` (when the value
    was recorded, which may be days after ``date``).
    """
    definitions = habits(events)
    live = definitions[~definitions["deleted"]]
    names = dict(zip(live["habit_id"], live["name"]))

    rows = collect_things(events, "habits", "habit_entry_recorded", "habit_entry")
    rows = [row for row in rows if not row["deleted"] and row.get("habit_id") in names]
    rows = latest_per(rows, "habit_id", "date")

    result = table(rows, ["date", "habit_id", "value", "skipped", "note", "recorded_utc"])
    result["date"] = as_dates(result["date"])
    result = result.dropna(subset=["date"])
    result.insert(2, "habit", result["habit_id"].map(names))
    result["skipped"] = result["skipped"].eq(True)
    return result.sort_values(["date", "habit"]).reset_index(drop=True)


def habit_days(events):
    """The habit grid: one row per day, one column per habit.

    Every day from the first entry to the last is included, so a missing
    value (NaN) always means "nothing recorded". For yes/no habits the
    values are ``True`` and ``False``. Columns are habit names; if two
    habits share a name, the later one gets " (2)" added.
    """
    entries = habit_entries(events)
    if entries.empty:
        return pd.DataFrame(index=pd.DatetimeIndex([], name="date"))
    grid = entries.pivot(index="date", columns="habit_id", values="value")
    days = pd.date_range(entries["date"].min(), entries["date"].max(), name="date")
    grid = grid.reindex(days)

    definitions = habits(events).set_index("habit_id")
    order = [habit for habit in definitions.index if habit in grid.columns]
    grid = grid[order]
    grid.columns = _unique(definitions.loc[order, "name"].tolist())
    grid.columns.name = None
    return grid


def _unique(names):
    """Makes repeated names unique: ["Read", "Read"] -> ["Read", "Read (2)"]."""
    seen = {}
    result = []
    for name in names:
        seen[name] = seen.get(name, 0) + 1
        result.append(name if seen[name] == 1 else f"{name} ({seen[name]})")
    return result
