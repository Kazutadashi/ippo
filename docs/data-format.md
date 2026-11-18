# Data format

This document describes exactly how Ippo stores your data. It is written
for two kinds of readers:

- **People who want to use their own data**, for example in Python,
  a spreadsheet, or a text editor.
- **Contributors** who write code that reads or writes this data.

Format version: **1**


## Contents

1. [The big picture](#1-the-big-picture)
2. [Files and folders](#2-files-and-folders)
3. [Events](#3-events)
4. [Value types](#4-value-types)
5. [Changing and deleting things](#5-changing-and-deleting-things)
6. [Reading and merging](#6-reading-and-merging)
7. [Versions and compatibility](#7-versions-and-compatibility)
8. [Module: habits](#8-module-habits)
9. [Module: exercise](#9-module-exercise)
10. [Module: food](#10-module-food)
11. [Module: time tracking](#11-module-time-tracking)
12. [Module: sleep](#12-module-sleep)
13. [Loading the data in Python](#13-loading-the-data-in-python)


## 1. The big picture

Ippo never stores "the current state" of anything. Instead it keeps a
**log of events**: small records of things that happened, such as
"a habit was created" or "a set of 8 squats was done". The app works
out the current state by reading all events from oldest to newest.

This has a few useful effects:

- **Nothing is ever overwritten.** Fixing a mistake adds a new event;
  the old one stays. Your full history is always there.
- **Syncing is safe.** Each device only adds to its own file, so sync
  tools never see two devices change the same file.
- **The data is easy to analyze.** Each line is one plain JSON record,
  and the file is a complete, dated history.

Four rules guide every module:

1. **Record what happened, not a judgement.** Store "lights out at
   23:40", not "went to bed on time: yes". Goals live separately and
   can change without changing history.
2. **Everything has a stable id.** Entries point to the id of a habit,
   exercise, food or activity, never to its name. Renaming something
   does not break its history.
3. **Entries say which day they are about.** You might log yesterday's
   value this morning. The `date` field holds the day the entry counts
   for; `recorded_at` holds when it was typed.
4. **Units are fixed.** Weights are kilograms, energy is kilocalories,
   durations are seconds. Never "2 cups" or "1.5 hours".


## 2. Files and folders

You choose the data folder in the app. Ippo only reads and writes
inside it. The layout is:

```
<data folder>/
├── events/
│   ├── 019a8f3c-0000-7000-8000-000000000001.jsonl   one file per device
│   └── 019a8f3c-0000-7000-8000-000000000002.jsonl
└── backups/
    └── 019a8f3c-0000-7000-8000-000000000001/
        ├── 2026-10-01.jsonl                         monthly snapshots
        └── 2026-11-01.jsonl
```

### `events/<device id>.jsonl`

Each device (each install of the app) writes to exactly one file, named
after its **device id**. The device id is random and created once, when
the app is first set up. It is not the device's name: two phones can
both be called "my-phone", but their ids never clash.

- A device **only appends** to its own file. It never changes or removes
  existing lines, and never writes to another device's file.
- A device **reads every file** in `events/`, so it sees the data from
  all your devices.
- Each file is **one continuous log for all time**. It is never split
  by month or year. To take your data elsewhere, copy the `events/`
  folder.
- If you reinstall the app, the new install gets a new device id and a
  new file. The old file is still read, so no history is lost.

A file grows by roughly 5 MB per year of daily use, so size is not a
concern.

### `backups/<device id>/<YYYY-MM-DD>.jsonl`

Once a month, the first time the app runs in a new month, it copies its
own event file into `backups/`. The file name is the date of the copy.

Backups are only a safety net. **The app never reads them.** If an
event file is ever damaged, you can restore it from the latest backup by
hand. Backups contain events that are also in `events/`, so do not load
both into an analysis, or you will count things twice.

### Other files

Readers ignore anything else in the data folder, and ignore **hidden
files** (names starting with `.`) everywhere, including inside
`events/`. Sync tools use hidden files for their own work, for example
partly downloaded files.

Readers do read **every other file in `events/`**, whatever its name.
This matters because sync tools sometimes make conflict copies such as
`<device id>.sync-conflict-20261117-120000-ABCDEFG.jsonl`. Reading
those too means no event is ever lost; duplicates are removed by id
(see [section 6](#6-reading-and-merging)).


## 3. Events

### File encoding

Event files use [JSON Lines](https://jsonlines.org/):

- The text is UTF-8.
- Each line is one JSON object: one event.
- Lines end with a single newline character (`\n`).

Writers never write blank lines. Readers skip blank lines, in case a
person edits a file by hand.

Before appending, a writer checks that the file ends with `\n`. If it
does not (for example because the app was killed in the middle of a
write), the writer first adds a `\n`, so the damaged line stays on its
own and the new event starts on a fresh line.

### Event fields

Every event has these fields, in this order:

| Field | Type | Meaning |
| --- | --- | --- |
| `format_version` | integer | The version of this document the event follows. Currently `1`. |
| `id` | string | The event's unique id: a lowercase [UUIDv7](https://datatracker.ietf.org/doc/html/rfc9562). |
| `recorded_at` | string | When the event was written, as a [timestamp](#timestamps). |
| `device_id` | string | The id of the device that wrote the event. Always the same as the file name. |
| `device_name` | string | The device's name at the time, chosen by the user, for example `"my-phone"`. Only for display. |
| `module` | string | The module the event belongs to: `"habits"`, `"exercise"`, `"food"`, `"time_tracking"` or `"sleep"`. |
| `type` | string | What happened, for example `"habit_created"`. Each module lists its types below. |
| `data` | object | The details. Its fields depend on `module` and `type`. |

Example (one line in the file; wrapped here to fit):

```json
{"format_version":1,"id":"019a8f3c-5b2e-7c41-9d3a-2f6e8b1c4d5a",
 "recorded_at":"2026-11-17T21:04:11.123+09:00",
 "device_id":"019a8f3c-0000-7000-8000-000000000001","device_name":"my-phone",
 "module":"habits","type":"habit_entry_recorded",
 "data":{"habit_id":"019a8e10-1111-7000-8000-000000000001","date":"2026-11-17","value":12}}
```

### Ids

Ids are UUIDv7 strings, such as `019a8f3c-5b2e-7c41-9d3a-2f6e8b1c4d5a`.
A UUIDv7 starts with the time it was made, so sorting ids also roughly
sorts them by creation time. The rest is random, so two devices never
make the same id.

When an event **creates** something (a habit, a food, a logged set), the
new thing's id is **the id of the event that created it**. There is no
separate id field. Other events refer to it by that id.


## 4. Value types

These are the only kinds of values used inside `data`.

### Timestamps

An exact moment, written as [RFC 3339](https://datatracker.ietf.org/doc/html/rfc3339)
with milliseconds and the **local time zone offset**:

```
2026-11-17T21:04:11.123+09:00
2026-07-01T08:30:00.000-04:00
2026-01-05T12:00:00.000+00:00
```

The offset is required. It keeps both the local time (useful for "what
time of day do I do this?") and the exact moment (useful for ordering).
Writers always write `+00:00`, never `Z`, so every timestamp has the
same shape.

### Dates

A calendar day, `YYYY-MM-DD`, for example `"2026-11-17"`. Used for "the
day this entry counts for". It has no time zone: it is the day as you
lived it.

### Times of day

A local clock time, `HH:MM` in 24-hour form, for example `"23:40"` or
`"06:05"`.

### Durations

Whole **seconds**, as an integer. 25 minutes is `1500`.

### Numbers

JSON numbers. Fixed units are part of the field name, for example
`weight_kg` or `energy_kcal`. Where the user chooses the unit (for
example a habit counted in "pages"), the unit is stored on the
definition as plain text and is only a label.

### Optional fields

A field marked *optional* may be missing or `null`. Both mean "not
given". Readers treat them the same.


## 5. Changing and deleting things

Things are never changed in place. Instead, three kinds of event
describe changes to something that was created earlier:

| Event type | `data` | Meaning |
| --- | --- | --- |
| `<thing>_changed` | `target_id`, `changes` | Sets the fields listed in `changes` to new values. Fields not listed stay as they were. |
| `<thing>_deleted` | `target_id` | The thing is deleted. It disappears from the app, but its events remain in the file. |
| `<thing>_restored` | `target_id` | Undoes a deletion. |

`target_id` is the id of the thing (the id of the event that created
it). Example: renaming a habit and changing its target.

```json
{"format_version":1,"id":"019a9000-...","recorded_at":"2026-11-20T08:00:00.000+09:00",
 "device_id":"...","device_name":"my-desktop","module":"habits","type":"habit_changed",
 "data":{"target_id":"019a8e10-1111-7000-8000-000000000001",
         "changes":{"name":"Read before bed","target":{"kind":"at_least","value":15}}}}
```

**When changes conflict**, for example you change the same field on two
devices before they sync, the change with the latest `recorded_at` wins
(see [section 6](#6-reading-and-merging)). Because changes list single
fields, changing *different* fields on two devices keeps both changes.
Each field in `changes` replaces that whole field: changing `target`
means giving the complete new `target` object.

To keep the format small, each module lists which of its things support
`_changed`, `_deleted` and `_restored`.


## 6. Reading and merging

To build the current state, a reader:

1. **Lists** every non-hidden file in `events/`.
2. **Reads** each file line by line. A line that is not valid JSON, or
   that is missing a required field, is **skipped**, and the user is
   told how many lines were skipped and in which file. The file itself
   is never changed.
3. **Removes duplicates by `id`.** The same event can appear twice, for
   example in a sync conflict copy. Events with the same id are the
   same event; one copy is kept.
4. **Sorts** all events by `recorded_at` (as an exact moment, so
   offsets are taken into account). Events with the same moment are
   sorted by `id`, so every device gets exactly the same order.
   (A writer makes each of its events at least one millisecond later
   than its previous one, so events from one device keep the order in
   which they were made.)
5. **Applies** the events in that order. Later events win over earlier
   ones.

This is "last writer wins", using each device's clock. It is simple and
works well for one person using a few devices. If a device's clock is
badly wrong, its events can land in the wrong place, so the app warns
about events dated in the future.

### Last seen

For each device, the app shows the latest `recorded_at` it has read from
that device's file. This tells you whether sync has caught up. For
example, if your phone's last event is from yesterday but you logged
something on it this morning, the sync has not finished yet.


## 7. Versions and compatibility

Your devices may run different versions of Ippo, for example an older
version on a phone. The rules below make sure that never loses data.

**Inside format version 1**, changes may only *add* things:

- new event types,
- new optional fields in `data`,
- new allowed values (for example a new habit value type).

Readers therefore **skip what they do not know**:

- an unknown `module` or `type`: the event is skipped;
- an unknown field: the field is ignored;
- an unknown value (for example an unknown `value_type`): the thing
  using it is shown as "not supported by this version".

In each case the app tells the user that some data needs a newer
version. Skipped events still stay in the file, so a newer version will
show them.

**A new format version** (2, 3, ...) is only needed for a change that
old readers would misunderstand, such as changing what an existing
field means. Readers skip events with a `format_version` higher than
they know and warn the user. A newer app must always be able to read
every older format version.


## 8. Module: habits

`module` is `"habits"`.

A habit is something you want to do regularly. Each day, you can
record a value for it.

### Things in this module

| Thing | Created by | `_changed` | `_deleted` / `_restored` |
| --- | --- | --- | --- |
| habit | `habit_created` | yes | yes |
| habit entry | `habit_entry_recorded` | no (record again instead) | `_deleted` only |

### `habit_created`

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | For example `"Read"`. |
| `value_type` | string | What is recorded each day: `"yes_no"`, `"number"`, `"duration"` or `"time_of_day"`. Cannot be changed later. |
| `unit` | string, optional | Only for `"number"`: a label such as `"pages"` or `"cards"`. |
| `target` | object, optional | The goal. See below. If missing, any recorded value counts as done. |
| `frequency` | object | How often the goal applies: `{"times": 1, "per_days": 1}` means once a day; `{"times": 3, "per_days": 7}` means three times a week. |
| `description` | string, optional | A note for yourself. |
| `archived` | boolean, optional | `true` hides the habit without deleting it. Usually set later with `habit_changed`. |

`target` has two fields:

| Field | Meaning |
| --- | --- |
| `kind` | `"at_least"` or `"at_most"`. |
| `value` | A number (for `"number"`), seconds (for `"duration"`), or a time of day (for `"time_of_day"`). Not used for `"yes_no"`. |

Whether a day counts as "done" is worked out by the app from the
recorded value and the target. It is never stored. So if you change a
target, past days are judged by the new target, and the raw values stay
untouched.

For `"time_of_day"` habits, the app compares times on a clock that runs
from noon to noon, so that `"00:30"` counts as later than `"23:30"`.
This only affects how the app judges a day, never the stored values.

### `habit_entry_recorded`

| Field | Type | Meaning |
| --- | --- | --- |
| `habit_id` | string | The habit. |
| `date` | date | The day this entry counts for. |
| `value` | depends on `value_type`, optional | `yes_no`: `true` or `false`. `number`: a number. `duration`: seconds. `time_of_day`: `"HH:MM"`. |
| `skipped` | boolean, optional | `true` means "skipped on purpose today" (for example a rest day). Then `value` is left out. |
| `note` | string, optional | A note for the day. |

There is **one value per habit per day**. If several entries exist for
the same habit and date, the latest one wins. To correct a value, record
it again. To clear a day back to "nothing recorded", use
`habit_entry_deleted`.

**"No" and "nothing recorded" are different.** `value: false` means you
said you did not do it. No entry means you did not say anything. The app
may show both the same way, but the data keeps them apart, so an
analysis can tell a real "no" from a day you forgot to log.

Example: the four value types.

```json
"data":{"habit_id":"019a8e10-...-01","date":"2026-11-17","value":true}
"data":{"habit_id":"019a8e10-...-02","date":"2026-11-17","value":12}
"data":{"habit_id":"019a8e10-...-03","date":"2026-11-17","value":1500}
"data":{"habit_id":"019a8e10-...-04","date":"2026-11-17","value":"23:40"}
```


## 9. Module: exercise

`module` is `"exercise"`.

This module logs exercise sets. Exercises can be grouped into
**progressions**: ordered ladders where you move to a harder step once
you reach a target, as in many calisthenics programs. Exercises do not
have to belong to a progression, so the module also works for, say,
weight training.

> **Note:** the app currently only uses exercises and sets. Progressions
> and `progression_step_set` are part of the format so that data from
> other tools, or a later version, can use them; the app reads past such
> events without errors but does not show them.

### Things in this module

| Thing | Created by | `_changed` | `_deleted` / `_restored` |
| --- | --- | --- | --- |
| exercise | `exercise_created` | yes | yes |
| progression | `progression_created` | yes | yes |
| set | `set_recorded` | yes | yes |

### `exercise_created`

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | For example `"Box squat"`. |
| `measured_in` | string | `"reps"` or `"seconds"` (for holds such as a plank). Cannot be changed later. |
| `description` | string, optional | Notes on form, for example. |

### `progression_created`

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | For example `"Squat progression"`. |
| `steps` | list | The steps in order, easiest first. Each step is an object, see below. |

Each step:

| Field | Type | Meaning |
| --- | --- | --- |
| `exercise_id` | string | The exercise for this step. |
| `target_sets` | integer | How many sets to reach before moving up. |
| `target_reps` | integer, optional | Reps per set to reach (for `reps` exercises). |
| `target_seconds` | integer, optional | Seconds per set to reach (for `seconds` exercises). |

To change the steps, `progression_changed` replaces the whole `steps`
list.

### `progression_step_set`

Records which step you are on. The app writes this when you move up
(or down) a step.

| Field | Type | Meaning |
| --- | --- | --- |
| `progression_id` | string | The progression. |
| `step_number` | integer | The new current step, counting from 1. |
| `date` | date | The day the change counts for. |

These events also make a clean history of your promotions: "reached
step 4 on 2026-03-02".

### `set_recorded`

One set of one exercise.

| Field | Type | Meaning |
| --- | --- | --- |
| `exercise_id` | string | The exercise. |
| `date` | date | The day of the workout. |
| `set_number` | integer | 1 for the first set of this exercise that day, 2 for the next, and so on. |
| `reps` | integer, optional | Reps done (for `reps` exercises). |
| `seconds` | integer, optional | Seconds held (for `seconds` exercises). |
| `weight_kg` | number, optional | Added weight. Missing means body weight only. |
| `reps_in_reserve` | integer, optional | How many more reps you could have done. A common way to record effort. |
| `progression_id` | string, optional | The progression this set was part of. |
| `step_number` | integer, optional | The step you were on at the time. |
| `target_reps` | integer, optional | The target at the time. |
| `target_seconds` | integer, optional | The target at the time. |
| `note` | string, optional | A note. |

`step_number` and the targets are **copied into each set** when it is
logged. If you later change a progression, old sets still say what
step and target they were done at. This is what makes progress charts
honest: moving to a harder step usually means fewer reps, and the step
number shows that this drop is progress.


## 10. Module: food

`module` is `"food"`.

This module is a food diary. You keep a list of foods with their
nutrition values, and log what you eat.

### Things in this module

| Thing | Created by | `_changed` | `_deleted` / `_restored` |
| --- | --- | --- | --- |
| food | `food_created` | yes | yes |
| food entry | `food_entry_recorded` | yes | yes |

### Nutrients

Nutrient values always use these field names. They follow the names
used by [Open Food Facts](https://world.openfoodfacts.org/), so data
from there is easy to match.

| Field | Unit |
| --- | --- |
| `energy_kcal` | kilocalories |
| `proteins_g` | grams |
| `carbohydrates_g` | grams |
| `sugars_g` | grams |
| `fat_g` | grams |
| `saturated_fat_g` | grams |
| `fiber_g` | grams |
| `salt_g` | grams |

Only `energy_kcal` is required. The others are optional.

### `food_created`

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | For example `"Rolled oats"`. |
| `measured_in` | string | `"g"` for grams or `"ml"` for millilitres. |
| `nutrients_per_100` | object | Nutrients per 100 g or per 100 ml, using the fields above. |
| `servings` | list, optional | Handy portion sizes, such as `{"name": "bowl", "amount": 60}`. `amount` is in `measured_in` units. |

### `food_entry_recorded`

One thing eaten.

| Field | Type | Meaning |
| --- | --- | --- |
| `date` | date | The day it counts for. |
| `time` | time of day, optional | When it was eaten. |
| `meal` | string, optional | `"breakfast"`, `"lunch"`, `"dinner"` or `"snack"`. The app does not ask for a meal (it lists entries in the order they were eaten), so new entries leave this out; it is kept for data from older versions and other tools. |
| `food_id` | string, optional | The food. Missing for a quick entry (see below). |
| `name` | string | The food's name at the time, copied. |
| `amount` | number, optional | How much, in the food's `measured_in` units. |
| `measured_in` | string, optional | `"g"` or `"ml"`, copied from the food. |
| `nutrients` | object | The nutrients **for this amount**, worked out and copied when logged. |
| `note` | string, optional | A note. |

The nutrients are **copied into each entry**. If you later correct a
food's values, past days do not change silently. (The app may offer to
update past entries; that writes `food_entry_changed` events, so the
change is visible in the log.)

**Quick entries** have no `food_id`: you type a name and the energy
directly, for example `{"name": "Restaurant lunch", "nutrients":
{"energy_kcal": 850}}`. This is for when looking up each ingredient is
not worth it.


## 11. Module: time tracking

`module` is `"time_tracking"`.

This module records how you spend your time. You tap an activity to
start it, and starting another activity ends the previous one. So the
log is a list of **switches**, and the time blocks are worked out from
them.

### Things in this module

| Thing | Created by | `_changed` | `_deleted` / `_restored` |
| --- | --- | --- | --- |
| activity | `activity_created` | yes | yes |
| start | `activity_started` | yes | yes |
| stop | `activity_stopped` | yes | yes |

The `_changed` and `_deleted` events for starts and stops are named
`activity_start_changed`, `activity_start_deleted`, and so on.

### `activity_created`

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | For example `"Reading"`. |
| `category` | string, optional | A group, for example `"Leisure"`, used to combine activities in charts. |
| `color` | string, optional | A display colour, `"#RRGGBB"`. |

### `activity_started`

| Field | Type | Meaning |
| --- | --- | --- |
| `activity_id` | string | The activity. |
| `started_at` | timestamp | When it started. Usually the same as `recorded_at`, but you can set an earlier time ("I started ten minutes ago"). |

### `activity_stopped`

Ends the current activity without starting a new one, for example when
going to sleep (unless you track sleep as an activity).

| Field | Type | Meaning |
| --- | --- | --- |
| `stopped_at` | timestamp | When it stopped. |

### How time blocks are worked out

1. Take all starts and stops that are not deleted, with their changes
   applied.
2. Sort them by `started_at` / `stopped_at` (ties sorted by id).
3. Each start begins a block. The block ends at the next start or
   stop, whichever comes first.
4. A start with nothing after it is the **running** activity.
5. Time between a stop and the next start is **untracked**. It is never
   given to an activity.

A block that crosses midnight is one block in the data. When showing a
day, or making daily tables, it is split at midnight (local time).

Because blocks are made from switches, they can never overlap, even when
switches come from different devices.


## 12. Module: sleep

`module` is `"sleep"`.

This module records when you slept: the main sleep of each night, and
naps.

### Things in this module

| Thing | Created by | `_changed` | `_deleted` / `_restored` |
| --- | --- | --- | --- |
| sleep | `sleep_recorded` | yes | yes |

### `sleep_recorded`

One night or nap.

| Field | Type | Meaning |
| --- | --- | --- |
| `date` | date | The day it counts for. For a night, the day you **woke up**: the night from Sunday to Monday counts for Monday. For a nap, the day of the nap. |
| `kind` | string | `"night"` or `"nap"`. Cannot be changed later. |
| `started_at` | timestamp | When you went to bed (or lay down for the nap). |
| `ended_at` | timestamp | When you woke up. Always after `started_at`. |

Example: a night from 23:30 to 07:00.

```json
"data":{"date":"2026-11-18","kind":"night",
        "started_at":"2026-11-17T23:30:00.000+09:00",
        "ended_at":"2026-11-18T07:00:00.000+09:00"}
```

The duration is not stored; it is `ended_at` minus `started_at`. Exact
timestamps keep it right across midnight and daylight saving changes,
and the offsets keep the local clock times (bedtime 23:30) for
analysis.

To change the times, `sleep_changed` gives new `started_at` and
`ended_at`.

If more than one night is recorded for the same `date`, the app shows
the latest one.


## 13. Loading the data in Python

A helper package for Python is planned. It will turn these events into
tidy tables (one row per habit entry, set, food entry or time block),
with changes and deletions already applied.

Until then, the raw events load with pandas alone:

```python
import json
from pathlib import Path

import pandas as pd

rows = []
for path in Path("/path/to/data/events").iterdir():
    if path.name.startswith("."):
        continue  # hidden files belong to sync tools
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            rows.append(json.loads(line))

events = pd.DataFrame(rows).drop_duplicates("id")
events["recorded_at"] = pd.to_datetime(events["recorded_at"], utc=True)
events = events.sort_values(["recorded_at", "id"])

# Expand "data" into columns, for example for habit entries:
entries = events[events["type"] == "habit_entry_recorded"]
entries = pd.concat(
    [entries.drop(columns="data").reset_index(drop=True),
     pd.json_normalize(entries["data"].tolist())],
    axis=1,
)
```

This simple version does not apply `_changed` or `_deleted` events, and
will stop at a damaged line. The helper package will handle both.
