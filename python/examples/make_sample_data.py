# SPDX-License-Identifier: GPL-3.0-or-later
"""Makes four years of made-up Ippo data, to try analyses on.

Usage:

    python make_sample_data.py /path/to/sample-folder

The person is invented, and so is everything they do. The data is
written straight from ``docs/data-format.md``, as any other tool could,
and includes the untidy parts of real use:

- two devices, a sync conflict copy, a hidden temporary file and one
  cut-off line;
- habit values changed, days left empty, days filled in the next
  morning, a habit added and another deleted;
- quick food entries with energy only, and deleted entries;
- bedtimes after midnight, missing nights, naps, and two weeks abroad
  in another time zone;
- slow progress: more push-ups, earlier bedtimes, steadier habits.

Short nights make the next day a little worse (fewer habits done, more
food), so there is something to find.
"""

import json
import math
import random
import shutil
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

START = date(2022, 11, 18)
DAYS = 4 * 365
PHONE = "019a0000-0000-7000-8000-00000000a001"
DESKTOP = "019a0000-0000-7000-8000-00000000b002"
HOME = timezone(timedelta(hours=1))
ABROAD = timezone(timedelta(hours=-5))
ABROAD_DAYS = range(900, 914)

random.seed(42)
events = {PHONE: [], DESKTOP: []}


def new_id(moment):
    """A UUIDv7: the time in milliseconds, then random bits."""
    milliseconds = int(moment.timestamp() * 1000)
    hex_digits = f"{(milliseconds << 80) | random.getrandbits(80):032x}"
    hex_digits = hex_digits[:12] + "7" + hex_digits[13:16] + "8" + hex_digits[17:]
    parts = (hex_digits[:8], hex_digits[8:12], hex_digits[12:16], hex_digits[16:20], hex_digits[20:])
    return "-".join(parts)


def stamp(moment):
    """A timestamp as the format writes it: milliseconds and an offset."""
    return moment.isoformat(timespec="milliseconds")


def day_text(day):
    return (START + timedelta(days=day)).isoformat()


def at(day, hours):
    """The moment ``hours`` after midnight on ``day``, in local time."""
    calendar_day = START + timedelta(days=day)
    zone = ABROAD if day in ABROAD_DAYS else HOME
    midnight = datetime(calendar_day.year, calendar_day.month, calendar_day.day, tzinfo=zone)
    return midnight + timedelta(hours=hours)


def write(device, moment, module, event_type, data):
    """Adds one event and returns its id."""
    event_id = new_id(moment)
    events[device].append({
        "format_version": 1,
        "id": event_id,
        "recorded_at": stamp(moment),
        "device_id": device,
        "device_name": "my-phone" if device == PHONE else "my-desktop",
        "module": module,
        "type": event_type,
        "data": data,
    })
    return event_id


# Habits, foods and exercises -------------------------------------------
def new_habit(day, name):
    data = {"name": name, "value_type": "yes_no", "frequency": {"times": 1, "per_days": 1}}
    return write(PHONE, at(day, 8), "habits", "habit_created", data)


habit_chance = {new_habit(0, "Read"): 0.55, new_habit(0, "Stretch"): 0.45,
                new_habit(0, "Walk"): 0.7}
meditate = new_habit(0, "Meditate")
habit_chance[meditate] = 0.3
guitar = None

FOODS = {
    "Rolled oats": ("g", {"energy_kcal": 389, "proteins_g": 13.2, "carbohydrates_g": 66, "fat_g": 6.5},
                    {"unit": "bowl", "count": 1, "amount": 60}),
    "Potato chips": ("g", {"energy_kcal": 536, "proteins_g": 7, "carbohydrates_g": 53, "fat_g": 34},
                     {"unit": "chips", "count": 9, "amount": 28}),
    "Rice, cooked": ("g", {"energy_kcal": 130, "proteins_g": 2.7, "carbohydrates_g": 28, "fat_g": 0.3}, None),
    "Chicken breast": ("g", {"energy_kcal": 165, "proteins_g": 31, "carbohydrates_g": 0, "fat_g": 3.6}, None),
    "Milk": ("ml", {"energy_kcal": 64, "proteins_g": 3.4, "carbohydrates_g": 4.8, "fat_g": 3.6}, None),
}
food_ids = {}
for name, (unit, per_100, serving) in FOODS.items():
    data = {"name": name, "measured_in": unit, "nutrients_per_100": per_100}
    if serving:
        data["serving"] = serving
    food_ids[name] = write(PHONE, at(0, 9), "food", "food_created", data)

push_up = write(PHONE, at(0, 18), "exercise", "exercise_created", {"name": "Push-up", "measured_in": "reps"})
squat = write(PHONE, at(0, 18), "exercise", "exercise_created", {"name": "Squat", "measured_in": "reps"})
plank = write(PHONE, at(0, 18), "exercise", "exercise_created", {"name": "Plank", "measured_in": "seconds"})


def eat(device, day, hours, name, amount, pieces=None):
    unit, per_100, serving = FOODS[name]
    data = {
        "date": day_text(day),
        "time": at(day, hours).strftime("%H:%M"),
        "food_id": food_ids[name],
        "name": name,
        "amount": amount,
        "measured_in": unit,
        "nutrients": {key: round(value * amount / 100, 1) for key, value in per_100.items()},
    }
    if pieces:
        data["unit_count"] = pieces
        data["unit_name"] = serving["unit"]
    return write(device, at(day, hours + 0.05), "food", "food_entry_recorded", data)


# Each day ----------------------------------------------------------------
last_bedtime = None
for day in range(DAYS):
    progress = day / DAYS
    weekend = (START + timedelta(days=day)).weekday() >= 5
    abroad = day in ABROAD_DAYS

    if day == 500:
        guitar = new_habit(day, "Practice guitar")
        habit_chance[guitar] = 0.4
    if day == 1000:
        write(PHONE, at(day, 20), "habits", "habit_deleted", {"target_id": meditate})
        del habit_chance[meditate]

    # Sleep: woke up this morning; bed tonight, sometimes after midnight.
    woke = at(day, 7 + (1 if weekend else 0) + random.gauss(0, 0.4))
    slept = (woke - last_bedtime).total_seconds() / 3600 if last_bedtime else 8
    short_night = slept < 7
    bedtime = at(day, random.gauss(23.4 + (0.5 if weekend else 0) - 0.4 * progress, 0.7))
    if random.random() > 0.06:
        write(PHONE, woke + timedelta(minutes=random.randint(2, 40)), "sleep", "woke_up_recorded",
              {"date": day_text(day), "at": stamp(woke)})
    if random.random() > 0.08:
        write(PHONE, bedtime + timedelta(minutes=random.randint(0, 10)), "sleep", "went_to_bed_recorded",
              {"date": day_text(day), "at": stamp(bedtime)})
    last_bedtime = bedtime
    if weekend and random.random() < 0.1:
        start = at(day, 14 + random.random())
        end = start + timedelta(minutes=random.randint(15, 70))
        write(PHONE, end + timedelta(minutes=5), "sleep", "nap_recorded",
              {"date": day_text(day), "started_at": stamp(start), "ended_at": stamp(end)})

    # Food: a little less as the years go on, a little more after short nights.
    if random.random() > 0.04:
        breakfast = eat(PHONE, day, 7.5, "Rolled oats", 60, pieces=1)
        eat(PHONE, day, 7.6, "Milk", 200)
        if random.random() < 0.02:
            write(PHONE, at(day, 22), "food", "food_entry_deleted", {"target_id": breakfast})
    lunch_device = DESKTOP if not (weekend or abroad) else PHONE
    if random.random() > 0.08:
        eat(lunch_device, day, 12.3, "Rice, cooked", random.choice([150, 200, 250]) - int(40 * progress))
        eat(lunch_device, day, 12.4, "Chicken breast", random.choice([100, 150]))
    if random.random() < 0.45 - 0.2 * progress + (0.25 if short_night else 0):
        chips = random.choice([9, 12, 18, 27])
        eat(PHONE, day, 16 + random.random(), "Potato chips", round(chips * 28 / 9, 1), pieces=chips)
    if abroad or random.random() < (0.35 if weekend else 0.15):
        dinner = at(day, 19 + random.random())
        write(PHONE, dinner + timedelta(minutes=40), "food", "food_entry_recorded", {
            "date": day_text(day), "time": dinner.strftime("%H:%M"), "name": "Restaurant dinner",
            "nutrients": {"energy_kcal": random.randint(700, 1200)},
        })
    else:
        eat(PHONE, day, 19, "Rice, cooked", 200)
        eat(PHONE, day, 19.5, "Chicken breast", 150)

    # Exercise, about every other day: push-ups improve, then level off.
    if random.random() < (0.1 if abroad else 0.5):
        best = 12 + 18 * (1 - math.exp(-3 * progress)) + random.gauss(0, 1.5)
        for number in range(random.choice([3, 3, 4])):
            reps = max(1, round(best - number * random.uniform(1, 3)))
            data = {"exercise_id": push_up, "date": day_text(day), "set_number": number + 1, "reps": reps}
            set_id = write(PHONE, at(day, 18 + number / 20), "exercise", "set_recorded", data)
            if random.random() < 0.01:
                write(PHONE, at(day, 18.7), "exercise", "set_changed",
                      {"target_id": set_id, "changes": {"reps": reps + 1}})
        for number in range(3):
            write(PHONE, at(day, 18.5 + number / 30), "exercise", "set_recorded", {
                "exercise_id": squat, "date": day_text(day), "set_number": number + 1,
                "reps": round(20 + 10 * progress + random.gauss(0, 2)),
            })
        write(PHONE, at(day, 18.75), "exercise", "set_recorded", {
            "exercise_id": plank, "date": day_text(day), "set_number": 1,
            "seconds": round(40 + 50 * progress + random.gauss(0, 6)),
        })

    # Habits: steadier with time, worse abroad and after short nights.
    for habit, chance in habit_chance.items():
        if random.random() < 0.1:
            continue  # nothing recorded that day
        chance += 0.3 * progress
        chance -= (0.3 if abroad else 0) + (0.1 if weekend else 0) + (0.2 if short_night else 0)
        done = random.random() < chance
        filled_in_next_morning = random.random() < 0.15
        moment = at(day + 1, 8.25) if filled_in_next_morning else at(day, 21 + random.random() * 0.8)
        device = DESKTOP if random.random() < 0.2 else PHONE
        data = {"habit_id": habit, "date": day_text(day), "value": done}
        write(device, moment, "habits", "habit_entry_recorded", data)
        if random.random() < 0.02:
            # Tapped the wrong mark, then fixed it: the later value wins.
            fixed = dict(data, value=not done)
            write(device, moment + timedelta(minutes=2), "habits", "habit_entry_recorded", fixed)

# Write the folder as a synced one would look ------------------------------
out = Path(sys.argv[1])
if out.exists():
    shutil.rmtree(out)
(out / "events").mkdir(parents=True)
for device, device_events in events.items():
    device_events.sort(key=lambda event: event["id"])  # the order they were made
    lines = [json.dumps(event, separators=(",", ":"), ensure_ascii=False) for event in device_events]
    if device == DESKTOP:
        # The app was stopped in the middle of a write once.
        middle = len(lines) // 2
        lines.insert(middle, lines[middle][:57])
    (out / "events" / f"{device}.jsonl").write_text("\n".join(lines) + "\n", encoding="utf-8")
phone_lines = (out / "events" / f"{PHONE}.jsonl").read_text(encoding="utf-8").splitlines(keepends=True)
conflict = out / "events" / f"{PHONE}.sync-conflict-20260601-120000-ABCDEFG.jsonl"
conflict.write_text("".join(phone_lines[: len(phone_lines) * 6 // 10]), encoding="utf-8")
(out / "events" / f".syncthing.{PHONE}.jsonl.tmp").write_text("half a file", encoding="utf-8")

total = sum(len(device_events) for device_events in events.values())
print(f"Wrote {total} events into {out}")
