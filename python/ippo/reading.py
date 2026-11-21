# SPDX-License-Identifier: GPL-3.0-or-later
"""Reading the event files of a data folder into one table.

This follows "Reading and merging" in ``docs/data-format.md``, the same
way the app does:

1. read every file in ``events/`` except hidden ones (names starting
   with ``.``), so sync conflict copies are included;
2. skip lines that are not valid events, and remember why;
3. set aside events from a newer format version;
4. remove repeated events by ``id``;
5. sort by the exact moment each event was recorded, then by ``id``.
"""

import json
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pandas as pd

#: The newest format version this package understands.
FORMAT_VERSION = 1

#: Events recorded more than this far in the future are counted, because
#: they usually mean a device's clock is wrong.
FUTURE_TOLERANCE = timedelta(minutes=5)

_UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")

# A timestamp must have a time zone: "Z" or an offset such as "+02:00".
_TIMESTAMP = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$"
)

_TEXT_FIELDS = ("id", "recorded_at", "device_id", "device_name", "module", "type")


@dataclass(frozen=True)
class Problem:
    """A line that was skipped because it is not a valid event.

    The file itself is never changed. Usually this is the last line of a
    file whose write was cut off, which is harmless.
    """

    file: str
    line: int
    reason: str

    def __str__(self):
        return f"{self.file} line {self.line}: {self.reason}"


@dataclass(frozen=True)
class Moment:
    """One timestamp, read two ways.

    ``utc`` is the exact moment, good for ordering and for durations.
    ``local`` is the clock time where the user was, without a time zone,
    good for questions like "what time do I go to bed?".
    """

    utc: datetime
    local: datetime


def parse_timestamp(text):
    """Reads a timestamp such as ``2026-11-17T21:04:11.123+02:00``.

    Returns a :class:`Moment`, or ``None`` if ``text`` is not a valid
    timestamp with a time zone. A timestamp without a time zone is
    refused on purpose: it could mean different moments on different
    devices.
    """
    if not isinstance(text, str) or not _TIMESTAMP.match(text):
        return None
    try:
        moment = datetime.fromisoformat(text)
    except ValueError:  # an impossible value, such as month 13
        return None
    return Moment(
        utc=moment.astimezone(timezone.utc),
        local=moment.replace(tzinfo=None),
    )


def read_events(folder, now=None):
    """Reads and merges every event file in ``folder``.

    ``folder`` is the data folder (the one holding ``events/``). ``now``
    is used to find events from the future; tests pass a fixed time.

    Returns ``(events, problems, newer_count, future_count)``:

    - ``events``: a DataFrame with one row per event, oldest first. The
      columns are the event fields (``app_version`` and ``time_zone``
      empty when an event does not have them), plus ``recorded_utc`` and
      ``recorded_local`` (see :class:`Moment`) and ``file``.
    - ``problems``: a list of :class:`Problem` for skipped lines.
    - ``newer_count``: how many events were set aside because they need
      a newer version of this package.
    - ``future_count``: how many events were recorded in the future.
    """
    events_folder = Path(folder) / "events"
    if not events_folder.is_dir():
        raise FileNotFoundError(
            f"{events_folder} does not exist. Please pass the data folder "
            "that holds the events/ folder."
        )

    rows = []
    problems = []
    newer_count = 0
    for path in sorted(events_folder.iterdir()):
        if path.name.startswith(".") or not path.is_file():
            continue  # hidden files belong to sync tools
        text = path.read_text(encoding="utf-8", errors="replace")
        for number, line in enumerate(text.split("\n"), start=1):
            line = line.strip()
            if not line:
                continue
            event, reason = _read_line(line)
            if event is None:
                problems.append(Problem(path.name, number, reason))
            elif event["format_version"] > FORMAT_VERSION:
                newer_count += 1
            else:
                event["file"] = path.name
                rows.append(event)

    columns = [
        "format_version", "id", "recorded_at", "recorded_utc", "recorded_local",
        "device_id", "device_name", "app_version", "time_zone", "module", "type", "data", "file",
    ]
    events = pd.DataFrame(rows, columns=columns)
    # The same event can be in a file and in its conflict copy.
    events = events.drop_duplicates("id")
    events["recorded_utc"] = pd.to_datetime(events["recorded_utc"], utc=True)
    events["recorded_local"] = pd.to_datetime(events["recorded_local"])
    events = events.sort_values(["recorded_utc", "id"]).reset_index(drop=True)

    now = now or datetime.now(timezone.utc)
    future_count = int((events["recorded_utc"] > now + FUTURE_TOLERANCE).sum())
    return events, problems, newer_count, future_count


def _read_line(line):
    """Reads one line. Returns ``(event, None)``, or ``(None, reason)``."""
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        return None, "not valid JSON"
    if not isinstance(event, dict):
        return None, "not a JSON object"

    version = event.get("format_version")
    # bool is a kind of int in Python, so it is ruled out by hand.
    if not isinstance(version, int) or isinstance(version, bool) or version < 1:
        return None, '"format_version" is not a positive integer'
    for name in _TEXT_FIELDS:
        if not isinstance(event.get(name), str) or not event[name]:
            return None, f'"{name}" is missing or not text'
    if not _UUID.match(event["id"]):
        return None, '"id" is not a lowercase UUID'
    moment = parse_timestamp(event["recorded_at"])
    if moment is None:
        return None, '"recorded_at" is not a timestamp with a time zone'
    if not isinstance(event.get("data"), dict):
        return None, '"data" is not a JSON object'

    return {
        "format_version": version,
        "id": event["id"],
        "recorded_at": event["recorded_at"],
        "recorded_utc": moment.utc,
        "recorded_local": moment.local,
        "device_id": event["device_id"],
        "device_name": event["device_name"],
        # Optional: events written before these were recorded lack them.
        "app_version": _optional_text(event.get("app_version")),
        "time_zone": _optional_text(event.get("time_zone")),
        "module": event["module"],
        "type": event["type"],
        "data": event["data"],
    }, None


def _optional_text(value):
    """Returns ``value`` if it is non-empty text, otherwise None."""
    return value if isinstance(value, str) and value else None
