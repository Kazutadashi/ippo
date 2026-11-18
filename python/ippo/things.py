# SPDX-License-Identifier: GPL-3.0-or-later
"""Working out the current state of "things" from their events.

See "Changing and deleting things" in ``docs/data-format.md``. A thing
(a habit, a food, a logged set, ...) is created by one event, and its id
is that event's id. Later events change some of its fields
(``<thing>_changed``), delete it (``<thing>_deleted``) or bring it back
(``<thing>_restored``). This file replays those events in order.
"""

import pandas as pd


def collect_things(events, module, created_type, thing_name):
    """Returns the current state of every thing of one kind.

    ``events`` is the table from :func:`ippo.reading.read_events`, oldest
    first. ``created_type`` is the event type that creates the thing, for
    example ``"food_created"``. ``thing_name`` is the start of the other
    event types, for example ``"food"`` for ``"food_changed"``.

    Returns a list of dictionaries, one per thing, in the order they were
    created. Each holds the thing's current fields, plus:

    - ``id``: the thing's id;
    - ``deleted``: whether it is deleted now;
    - ``recorded_utc``: when it was created.

    Changes to a thing whose creating event is missing (for example
    because it has not synced yet) are ignored, as in the app.
    """
    things = {}
    deleted = set()
    of_module = events[events["module"] == module]
    for event in of_module.itertuples(index=False):
        if event.type == created_type:
            things[event.id] = dict(event.data, id=event.id, recorded_utc=event.recorded_utc)
            continue
        target = event.data.get("target_id")
        if target not in things:
            continue
        if event.type == f"{thing_name}_changed":
            changes = event.data.get("changes")
            if isinstance(changes, dict):
                # Each listed field replaces the old value as a whole.
                # The id and creation time can never change.
                for field, value in changes.items():
                    if field not in ("id", "recorded_utc"):
                        things[target][field] = value
        elif event.type == f"{thing_name}_deleted":
            deleted.add(target)
        elif event.type == f"{thing_name}_restored":
            deleted.discard(target)

    result = list(things.values())
    for thing in result:
        thing["deleted"] = thing["id"] in deleted
    return result


def latest_per(rows, *keys):
    """Keeps only the latest row for each value of ``keys``.

    ``rows`` must be oldest first. Used for "one value per habit per
    day" and "one wake-up per day": if several were recorded, the latest
    one counts.
    """
    latest = {}
    for row in rows:
        latest[tuple(row[key] for key in keys)] = row
    return list(latest.values())


def table(rows, columns):
    """Turns a list of dictionaries into a DataFrame with exactly
    ``columns``, in that order. Missing fields become empty (NaN)."""
    result = pd.DataFrame(rows, columns=columns)
    if "deleted" in result.columns:
        # Always true/false, even in an empty table, so that filters such
        # as table[~table["deleted"]] work.
        result["deleted"] = result["deleted"].astype(bool)
    if "recorded_utc" in result.columns:
        result["recorded_utc"] = pd.to_datetime(result["recorded_utc"], utc=True)
    return result


def as_dates(series):
    """Turns ``YYYY-MM-DD`` text into pandas dates. Invalid dates become
    empty (NaT) rather than stopping the whole table."""
    return pd.to_datetime(series, format="%Y-%m-%d", errors="coerce")
