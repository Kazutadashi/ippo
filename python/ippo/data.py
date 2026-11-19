# SPDX-License-Identifier: GPL-3.0-or-later
"""The loaded data folder, with one method per table."""

import json
from pathlib import Path

import pandas as pd

from . import body, daily, exercise, food, habits, sleep
from .reading import read_events


def load(folder, now=None):
    """Loads the Ippo data folder at ``folder`` (the one holding
    ``events/``) and returns an :class:`IppoData`.

    ``now`` is only for tests: the moment used to spot events recorded in
    the future.
    """
    events, problems, newer_count, future_count = read_events(folder, now=now)
    return IppoData(events, problems, newer_count, future_count)


class IppoData:
    """Everything in one data folder.

    Each table method returns a fresh pandas DataFrame, with every
    change and deletion already applied, so the result is what the app
    shows. Tables are worked out once and remembered, so calling a
    method again is quick.

    Attributes:
        events: every event, one row each, oldest first. Use it for
            anything the tables do not cover; ``data`` holds each event's
            details as a dictionary.
        problems: lines that were skipped (see :class:`ippo.Problem`).
        newer_version_count: events skipped because they need a newer
            version of this package.
        future_count: events recorded in the future, which usually means
            a device's clock was wrong.
    """

    def __init__(self, events, problems, newer_version_count, future_count):
        self.events = events
        self.problems = problems
        self.newer_version_count = newer_version_count
        self.future_count = future_count
        self._tables = {}

    # Each method below is a thin, documented door to one table.

    def habits(self):
        """See :func:`ippo.habits.habits`."""
        return self._table(habits.habits)

    def habit_entries(self):
        """See :func:`ippo.habits.habit_entries`."""
        return self._table(habits.habit_entries)

    def habit_days(self):
        """See :func:`ippo.habits.habit_days`."""
        return self._table(habits.habit_days)

    def foods(self):
        """See :func:`ippo.food.foods`."""
        return self._table(food.foods)

    def food_entries(self):
        """See :func:`ippo.food.food_entries`."""
        return self._table(food.food_entries)

    def food_days(self):
        """See :func:`ippo.food.food_days`."""
        return self._table(food.food_days)

    def exercises(self):
        """See :func:`ippo.exercise.exercises`."""
        return self._table(exercise.exercises)

    def sets(self):
        """See :func:`ippo.exercise.sets`."""
        return self._table(exercise.sets)

    def exercise_days(self):
        """See :func:`ippo.exercise.exercise_days`."""
        return self._table(exercise.exercise_days)

    def steps(self):
        """See :func:`ippo.exercise.steps`."""
        return self._table(exercise.steps)

    def weights(self):
        """See :func:`ippo.body.weights`."""
        return self._table(body.weights)

    def profile(self):
        """See :func:`ippo.body.profile`."""
        return self._table(body.profile)

    def energy_targets(self):
        """See :func:`ippo.body.energy_targets`."""
        return self._table(body.energy_targets)

    def sleep_days(self):
        """See :func:`ippo.sleep.sleep_days`."""
        return self._table(sleep.sleep_days)

    def naps(self):
        """See :func:`ippo.sleep.naps`."""
        return self._table(sleep.naps)

    def daily(self):
        """See :func:`ippo.daily.daily`."""
        return self._table(daily.daily)

    def devices(self):
        """One row per device: its latest name, how many events it wrote,
        and when its first and last events were recorded. If a device's
        ``last_seen`` is old, sync may not have caught up yet."""
        grouped = self.events.groupby("device_id")
        result = pd.DataFrame({
            "device_name": grouped["device_name"].last(),
            "events": grouped.size(),
            "first_seen_utc": grouped["recorded_utc"].min(),
            "last_seen_utc": grouped["recorded_utc"].max(),
        })
        return result.reset_index()

    def summary(self):
        """A short text overview: what was loaded, and anything odd."""
        lines = [f"{len(self.events)} events from {self.events['device_id'].nunique()} device(s)"]
        for device in self.devices().itertuples():
            last = f"{device.last_seen_utc:%Y-%m-%d %H:%M}"
            lines.append(f"  {device.device_name}: {device.events} events, last {last} UTC")
        habit_count = (~self.habits()["deleted"]).sum()
        lines.append(
            f"{habit_count} habits, {len(self.habit_entries())} habit values, "
            f"{len(self.food_entries())} food entries, {len(self.sets())} sets, "
            f"{len(self.sleep_days())} days with sleep data"
        )
        if self.problems:
            lines.append(f"{len(self.problems)} line(s) skipped because they are not valid events:")
            lines.extend(f"  {problem}" for problem in self.problems)
        if self.newer_version_count:
            lines.append(f"{self.newer_version_count} event(s) need a newer version of this package.")
        if self.future_count:
            lines.append(f"{self.future_count} event(s) are dated in the future; is a device's clock wrong?")
        return "\n".join(lines)

    def export_csv(self, out_folder):
        """Writes every table, and the events, as CSV files into
        ``out_folder`` (created if needed). Returns the files written.

        The CSV files can be opened in a spreadsheet or read by any other
        program, without this package. Dates are written ``YYYY-MM-DD``,
        moments in UTC as ``YYYY-MM-DDTHH:MM:SS.sss+00:00``, and local
        clock times without a time zone.
        """
        out_folder = Path(out_folder)
        out_folder.mkdir(parents=True, exist_ok=True)
        tables = {name: getattr(self, name)() for name in TABLE_NAMES}
        events = self.events.copy()
        events["data"] = events["data"].map(lambda data: json.dumps(data, ensure_ascii=False))
        tables["events"] = events.drop(columns=["recorded_utc", "recorded_local"])

        written = []
        for name, frame in tables.items():
            path = out_folder / f"{name}.csv"
            index = frame.index.name == "date"
            _for_csv(frame).to_csv(path, index=index)
            written.append(path)
        return written

    def _table(self, build):
        if build not in self._tables:
            self._tables[build] = build(self.events)
        return self._tables[build].copy()


#: The tables written by :meth:`IppoData.export_csv`, besides the events.
TABLE_NAMES = [
    "habits", "habit_entries", "habit_days",
    "foods", "food_entries", "food_days",
    "exercises", "sets", "exercise_days", "steps",
    "sleep_days", "naps",
    "weights", "profile", "energy_targets",
    "daily", "devices",
]


def _for_csv(frame):
    """Writes dates and moments as plain, unambiguous text."""
    frame = frame.copy()
    if isinstance(frame.index, pd.DatetimeIndex):
        frame.index = frame.index.strftime("%Y-%m-%d")
    for column in frame.columns:
        values = frame[column]
        if isinstance(values.dtype, pd.DatetimeTZDtype):
            frame[column] = values.dt.strftime("%Y-%m-%dT%H:%M:%S.%f").str[:-3] + "+00:00"
        elif pd.api.types.is_datetime64_dtype(values):
            if column == "date":
                frame[column] = values.dt.strftime("%Y-%m-%d")
            else:
                frame[column] = values.dt.strftime("%Y-%m-%dT%H:%M:%S.%f").str[:-3]
    return frame
