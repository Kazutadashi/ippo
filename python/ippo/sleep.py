# SPDX-License-Identifier: GPL-3.0-or-later
"""Tables for the sleep module ("Module: sleep" in the data format).

A day runs from waking up to going to bed. Going to bed at 01:00 still
ends the day before. The sleep *before* a day is the time from the
previous day's bedtime to that day's wake-up.
"""

import pandas as pd

from .reading import parse_timestamp
from .things import as_dates, collect_things, latest_per


def sleep_days(events):
    """One row per day with a wake-up, a bedtime or a nap, indexed by date.

    Times are given three ways, for different questions:

    - ``woke_up_utc``, ``went_to_bed_utc``: exact moments.
    - ``woke_up_local``, ``went_to_bed_local``: the clock where you were.
    - ``woke_up_h``, ``went_to_bed_h``: hours after the day's midnight,
      ready to average and plot. A bedtime of 01:00 the next morning is
      ``25.0``, so it sorts after 23:00 rather than before 07:00.

    And worked out from them:

    - ``sleep_before_h``: hours from the previous day's bedtime to this
      wake-up (empty if either is missing).
    - ``time_zone_changed``: ``True`` if that bedtime and this wake-up
      were in different time zones, for example after a flight. Then
      ``sleep_before_h`` is real elapsed time, which may look odd.
    - ``awake_h``: hours from waking up to going to bed.
    - ``naps``, ``nap_h``: how many naps, and their total hours.
    """
    woke = _moments(events, "woke_up")
    bed = _moments(events, "went_to_bed")
    nap_table = naps(events)
    nap_totals = nap_table.groupby("date")["hours"].agg(naps="count", nap_h="sum")

    dates = sorted(set(woke) | set(bed) | set(nap_totals.index))
    rows = []
    for date in dates:
        woke_up = woke.get(date)
        went_to_bed = bed.get(date)
        bed_before = bed.get(date - pd.Timedelta(days=1))
        midnight = date.to_pydatetime()
        row = {"date": date}
        if woke_up:
            row["woke_up_utc"] = woke_up.utc
            row["woke_up_local"] = woke_up.local
            row["woke_up_h"] = _hours(woke_up.local - midnight)
        if went_to_bed:
            row["went_to_bed_utc"] = went_to_bed.utc
            row["went_to_bed_local"] = went_to_bed.local
            row["went_to_bed_h"] = _hours(went_to_bed.local - midnight)
        if woke_up and went_to_bed:
            row["awake_h"] = _hours(went_to_bed.utc - woke_up.utc)
        if woke_up and bed_before:
            slept = _hours(woke_up.utc - bed_before.utc)
            # A wake-up before the bedtime is a typing mistake; the app
            # shows nothing then, and so does this table.
            if slept > 0:
                row["sleep_before_h"] = slept
            row["time_zone_changed"] = _offset(woke_up) != _offset(bed_before)
        rows.append(row)

    columns = ["date", "woke_up_utc", "woke_up_local", "woke_up_h",
               "went_to_bed_utc", "went_to_bed_local", "went_to_bed_h",
               "sleep_before_h", "time_zone_changed", "awake_h"]
    result = pd.DataFrame(rows, columns=columns).set_index("date")
    for name in ("woke_up_utc", "went_to_bed_utc"):
        result[name] = pd.to_datetime(result[name], utc=True)
    for name in ("woke_up_local", "went_to_bed_local"):
        result[name] = pd.to_datetime(result[name])
    # True, False, or empty when there is nothing to compare.
    result["time_zone_changed"] = result["time_zone_changed"].astype("boolean")
    result = result.join(nap_totals)
    result["naps"] = result["naps"].fillna(0).astype(int)
    result["nap_h"] = result["nap_h"].fillna(0.0)
    return result


def naps(events):
    """One row per nap. Deleted naps are left out.

    Columns: ``nap_id``, ``date``, ``started_utc``, ``started_local``,
    ``ended_utc``, ``ended_local``, ``hours``.
    """
    rows = []
    for nap in collect_things(events, "sleep", "nap_recorded", "nap"):
        started = parse_timestamp(nap.get("started_at"))
        ended = parse_timestamp(nap.get("ended_at"))
        if nap["deleted"] or started is None or ended is None or ended.utc <= started.utc:
            continue
        rows.append({
            "nap_id": nap["id"],
            "date": nap.get("date"),
            "started_utc": started.utc,
            "started_local": started.local,
            "ended_utc": ended.utc,
            "ended_local": ended.local,
            "hours": _hours(ended.utc - started.utc),
        })
    columns = ["nap_id", "date", "started_utc", "started_local", "ended_utc", "ended_local", "hours"]
    result = pd.DataFrame(rows, columns=columns)
    result["date"] = as_dates(result["date"])
    for name in ("started_utc", "ended_utc"):
        result[name] = pd.to_datetime(result[name], utc=True)
    for name in ("started_local", "ended_local"):
        result[name] = pd.to_datetime(result[name])
    return result.dropna(subset=["date"]).sort_values("started_utc").reset_index(drop=True)


def _moments(events, kind):
    """The wake-ups (``kind`` ``"woke_up"``) or bedtimes
    (``"went_to_bed"``) by day, as :class:`ippo.reading.Moment`. If
    several were recorded for one day, the latest counts."""
    records = collect_things(events, "sleep", f"{kind}_recorded", kind)
    records = [record for record in records if not record["deleted"]]
    by_day = {}
    for record in latest_per(records, "date"):
        day = as_dates(pd.Series([record.get("date")]))[0]
        moment = parse_timestamp(record.get("at"))
        if pd.notna(day) and moment is not None:
            by_day[day] = moment
    return by_day


def _offset(moment):
    """The time zone offset of a moment: local clock minus UTC."""
    return moment.local - moment.utc.replace(tzinfo=None)


def _hours(duration):
    """A timedelta in hours, as a float."""
    return duration.total_seconds() / 3600
