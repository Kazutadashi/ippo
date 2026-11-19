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
13. [Using your data elsewhere](#13-using-your-data-elsewhere)


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
├── README.txt                                       what these files are
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

### `README.txt`

A short note saying what the folder holds, for anyone who finds it
without the app. The app writes it once if it is missing and never reads
it.

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
| `color` | string, optional | A display colour, `"#RRGGBB"`. Missing or `null` means the app's accent colour. |
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
it again. To clear a day back to "nothing recorded", every entry for
that habit and day is deleted with `habit_entry_deleted` (so an older
entry cannot reappear).

> **Note:** the app currently creates and shows `"yes_no"` habits only,
> marked ✓ (`value: true`) or ✗ (`value: false`). The other value types
> are part of the format for later versions and other tools.

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

This module logs exercise sets: how many reps of an exercise you did,
or how long you held it.

### Things in this module

| Thing | Created by | `_changed` | `_deleted` / `_restored` |
| --- | --- | --- | --- |
| exercise | `exercise_created` | yes | yes |
| set | `set_recorded` | yes | yes |

### `exercise_created`

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | For example `"Box squat"`. |
| `measured_in` | string | `"reps"` or `"seconds"` (for holds such as a plank). Cannot be changed later. |
| `description` | string, optional | Notes on form, for example. |

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
| `note` | string, optional | A note. |

A set has `reps` or `seconds`, never both, matching the exercise's
`measured_in`: the unit is part of the field name, as everywhere in this
format. To put all exercises in one column, take whichever is present
and keep the unit beside it (the Python package does this).


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

**A missing nutrient means "not known", never zero.** A quick entry
often gives only energy. When adding up a day, keep track of whether
every entry gave the nutrient; otherwise the day's protein, for
example, looks lower than it was.

### `food_created`

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | For example `"Rolled oats"`. |
| `measured_in` | string | `"g"` for grams or `"ml"` for millilitres. |
| `nutrients_per_100` | object | Nutrients per 100 g or per 100 ml, using the fields above. |
| `serving` | object, optional | The serving size from the label. See below. |

`serving` describes the label's serving size, such as "9 chips (28 g)":

| Field | Type | Meaning |
| --- | --- | --- |
| `unit` | string | The name of one piece, as on the label: `"chips"`, `"slices"`, `"cup"`. |
| `count` | number | How many pieces make one serving: `9`. May be a fraction, such as `0.667` for "2/3 cup". |
| `amount` | number | How much one serving weighs, in `measured_in` units: `28`. |

```json
"serving":{"unit":"chips","count":9,"amount":28}
```

It lets amounts be entered in pieces as well as in grams. Labels often
give nutrients per serving; the app turns those into
`nutrients_per_100`, so foods are always stored the same way. See
`docs/food-labels.md` for filling a food in from a label.

### `food_entry_recorded`

One thing eaten.

| Field | Type | Meaning |
| --- | --- | --- |
| `date` | date | The day it counts for. |
| `time` | time of day, optional | When it was eaten. |
| `food_id` | string, optional | The food. Missing for a quick entry (see below). |
| `name` | string | The food's name at the time, copied. |
| `amount` | number, optional | How much, in the food's `measured_in` units. |
| `measured_in` | string, optional | `"g"` or `"ml"`, copied from the food. |
| `unit_count` | number, optional | How many pieces, if the amount was entered in the food's serving unit ("9" chips). `amount` still holds the grams. |
| `unit_name` | string, optional | The name of those pieces, such as `"chips"`, copied from the food's `serving`. |
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

This module records when you woke up and went to bed each day, and
naps.

A **day** runs from waking up to going to bed. Going to bed at 01:00
still ends the day before, because you have not slept yet. So every
wake-up and bedtime has a `date`: the day it belongs to, which for a
bedtime after midnight is the calendar day before the timestamp. The
sleep *before* a day is the time from the previous day's bedtime to
that day's wake-up; it is worked out, never stored.

### Things in this module

| Thing | Created by | `_changed` | `_deleted` / `_restored` |
| --- | --- | --- | --- |
| woke up | `woke_up_recorded` | yes | yes |
| went to bed | `went_to_bed_recorded` | yes | yes |
| nap | `nap_recorded` | yes | yes |

### `woke_up_recorded` and `went_to_bed_recorded`

| Field | Type | Meaning |
| --- | --- | --- |
| `date` | date | The day this belongs to (see above). |
| `at` | timestamp | When you woke up, or went to bed. |

Example: a day from 07:00 to 01:00 the next calendar day.

```json
"type":"woke_up_recorded",     "data":{"date":"2026-11-18","at":"2026-11-18T07:00:00.000+09:00"}
"type":"went_to_bed_recorded", "data":{"date":"2026-11-18","at":"2026-11-19T01:00:00.000+09:00"}
```

To change the time, `woke_up_changed` or `went_to_bed_changed` gives a
new `at`. If more than one is recorded for the same `date`, the latest
one counts.

How long you slept before 2026-11-19 is that day's `woke_up` `at` minus
2026-11-18's `went_to_bed` `at`. Exact timestamps keep this right across
midnight and daylight saving changes, and the offsets keep the local
clock times for analysis.

### `nap_recorded`

One nap.

| Field | Type | Meaning |
| --- | --- | --- |
| `date` | date | The day of the nap. |
| `started_at` | timestamp | When the nap started. |
| `ended_at` | timestamp | When it ended. Always after `started_at`. |

To change the times, `nap_changed` gives new `started_at` and
`ended_at`.

### Time zones

Each timestamp keeps the offset of the place you were. Across a flight,
the bedtime and the next wake-up have different offsets, and the sleep
worked out from exact moments is real elapsed time: perhaps 2 hours
flying east, or 14 flying west. That is correct, but it is not a normal
night, so analyses usually flag or leave out such nights. Clock times
("woke up at 07:00") are best read from the local time written in the
timestamp, which is the time on the clock where you were.


## 13. Using your data elsewhere

Everything above is enough to write a reader in any language. Most
people will not need to.

**In Python**, the package in the `python/` folder of this repository
reads a data folder into pandas tables, with changes and deletions
applied and one row per day ready for charts:

```python
import ippo

data = ippo.load("/path/to/data")
daily = data.daily()
```

See `python/README.md` for every table.

**In a spreadsheet or another program**, the same package writes every
table as a CSV file:

```
python -m ippo export /path/to/data /path/to/csv-folder
```

**Writing your own reader?** The folder `example-data/` holds a small
data folder with every awkward case: two devices, a sync conflict copy,
a hidden file, a cut-off line, a newer format version, an unknown
module, a backup, changes, deletions, a cleared habit day, a bedtime
after midnight and a time zone change. The app's tests
(`test/example_data_test.dart`) and the Python package's tests
(`python/tests/`) both check what a correct reader gets from it, such as
"6 h 45 min of sleep before 2 March". A reader that gets the same
answers handles the format correctly.
