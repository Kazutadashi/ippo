# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests against the example data folder at the top of the repository.

The folder holds every awkward case on purpose: a sync conflict copy, a
hidden file, a cut-off line, a backup, changes, deletions, a bedtime
after midnight and a time zone change. The app's own tests
(``test/example_data_test.dart``) check the same answers, so the app
and this package are known to agree.

Run from the ``python`` folder with: ``python -m unittest``
"""

import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

import ippo

EXAMPLE = Path(__file__).resolve().parents[2] / "example-data"
NOW = datetime(2026, 3, 5, tzinfo=timezone.utc)


def day(text):
    return pd.Timestamp(text)


class ReadingTest(unittest.TestCase):
    def setUp(self):
        self.data = ippo.load(EXAMPLE, now=NOW)

    def test_every_event_is_read_once(self):
        # 39 events were written; one needs a newer version. The conflict
        # copy only repeats events, and the hidden file is not read.
        self.assertEqual(len(self.data.events), 48)
        self.assertTrue(self.data.events["id"].is_unique)
        self.assertNotIn("019cffff-0000-7000-8000-00000000ffff", set(self.data.events["id"]))

    def test_the_cut_off_line_is_reported(self):
        [problem] = self.data.problems
        self.assertEqual(problem.file, "019c0000-0000-7000-8000-00000000b002.jsonl")
        self.assertEqual(problem.reason, "not valid JSON")

    def test_newer_and_future_events_are_counted(self):
        self.assertEqual(self.data.newer_version_count, 1)
        self.assertEqual(self.data.future_count, 0)
        early = ippo.load(EXAMPLE, now=datetime(2026, 3, 2, tzinfo=timezone.utc))
        self.assertGreater(early.future_count, 0)

    def test_events_are_sorted_by_exact_moment(self):
        self.assertTrue(self.data.events["recorded_utc"].is_monotonic_increasing)

    def test_devices(self):
        devices = self.data.devices().set_index("device_name")
        self.assertEqual(devices.loc["my-phone", "events"], 45)
        self.assertEqual(devices.loc["my-desktop", "events"], 3)

    def test_a_folder_without_events_is_explained(self):
        with tempfile.TemporaryDirectory() as empty:
            with self.assertRaises(FileNotFoundError):
                ippo.load(empty)


class HabitsTest(unittest.TestCase):
    def setUp(self):
        self.data = ippo.load(EXAMPLE, now=NOW)

    def test_renames_and_deletions_are_applied(self):
        habits = self.data.habits().set_index("name")
        self.assertIn("Evening walk", habits.index)
        self.assertTrue(habits.loc["Stretch", "deleted"])

    def test_frequency_columns_default_to_every_day(self):
        habits = self.data.habits().set_index("name")
        self.assertEqual(habits.loc["Read", "times"], 1)
        self.assertEqual(habits.loc["Read", "per_days"], 1)

    def test_odd_frequencies_mean_every_day(self):
        from ippo.habits import _frequency
        self.assertEqual(_frequency({"times": 3, "per_days": 7}), (3, 7))
        for odd in [None, "daily", {"times": 5, "per_days": 3}, {"times": 1.5, "per_days": 7}, {"times": True, "per_days": 2}]:
            self.assertEqual(_frequency(odd), (1, 1))

    def test_one_value_per_habit_per_day_latest_wins(self):
        entries = self.data.habit_entries()
        values = {(row.habit, row.date): row.value for row in entries.itertuples()}
        self.assertEqual(values, {
            ("Read", day("2026-03-01")): True,
            ("Read", day("2026-03-02")): False,   # changed from True
            ("Read", day("2026-03-03")): True,    # logged a day late
            ("Evening walk", day("2026-03-01")): False,
            # Walk on 2 March was cleared; Stretch was deleted.
        })

    def test_the_grid_keeps_no_and_nothing_apart(self):
        grid = self.data.habit_days()
        self.assertEqual(list(grid.columns), ["Read", "Evening walk"])
        self.assertIs(grid.loc["2026-03-01", "Evening walk"], False)
        self.assertTrue(pd.isna(grid.loc["2026-03-02", "Evening walk"]))


class FoodTest(unittest.TestCase):
    def setUp(self):
        self.data = ippo.load(EXAMPLE, now=NOW)

    def test_changes_and_deletions_are_applied(self):
        entries = self.data.food_entries()
        self.assertEqual(list(entries["energy_kcal"]), [190, 850, 285])
        self.assertEqual(list(entries["quick"]), [False, True, False])

    def test_missing_nutrients_are_not_zero(self):
        days = self.data.food_days()
        self.assertEqual(days.loc["2026-03-01", "energy_kcal"], 1040)
        self.assertTrue(days.loc["2026-03-01", "energy_kcal_complete"])
        # The quick lunch has no protein, so that total is incomplete.
        self.assertEqual(days.loc["2026-03-01", "proteins_g"], 6.5)
        self.assertFalse(days.loc["2026-03-01", "proteins_g_complete"])
        self.assertTrue(days.loc["2026-03-02", "proteins_g_complete"])
        self.assertTrue(pd.isna(days.loc["2026-03-02", "sugars_g"]))

    def test_foods_have_their_serving(self):
        oats = self.data.foods().iloc[0]
        self.assertEqual((oats["serving_unit"], oats["serving_amount"]), ("bowl", 50))
        self.assertEqual(oats["energy_kcal_per_100"], 380)


class ExerciseTest(unittest.TestCase):
    def setUp(self):
        self.data = ippo.load(EXAMPLE, now=NOW)

    def test_reps_and_seconds_share_one_value_column(self):
        sets = self.data.sets()
        self.assertEqual(list(zip(sets["exercise"], sets["value"], sets["unit"])), [
            ("Push-up", 10, "reps"), ("Push-up", 12, "reps"), ("Push-up", 11, "reps"),
            ("Plank", 60, "seconds"),
            ("Push-up", 14, "reps"),   # changed from 13; the 9 was deleted
        ])

    def test_best_set_per_day(self):
        days = self.data.exercise_days()
        push_ups = days[days["exercise"] == "Push-up"]
        self.assertEqual(list(push_ups["best"]), [12, 14])
        self.assertEqual(list(push_ups["sets"]), [3, 1])


class SleepTest(unittest.TestCase):
    def setUp(self):
        self.days = ippo.load(EXAMPLE, now=NOW).sleep_days()

    def test_a_bedtime_after_midnight_counts_past_24(self):
        self.assertEqual(self.days.loc["2026-03-01", "went_to_bed_h"], 24.5)
        self.assertEqual(self.days.loc["2026-03-01", "awake_h"], 17.5)

    def test_sleep_before_a_day_uses_the_changed_wake_up(self):
        self.assertEqual(self.days.loc["2026-03-02", "woke_up_h"], 7.25)
        self.assertEqual(self.days.loc["2026-03-02", "sleep_before_h"], 6.75)
        self.assertFalse(self.days.loc["2026-03-02", "time_zone_changed"])

    def test_a_time_zone_change_is_flagged(self):
        row = self.days.loc["2026-03-03"]
        self.assertEqual(row["woke_up_h"], 6.0)          # the local clock
        self.assertEqual(row["sleep_before_h"], 13.0)    # real elapsed time
        self.assertTrue(row["time_zone_changed"])

    def test_naps(self):
        self.assertEqual(self.days.loc["2026-03-02", "nap_h"], 0.5)
        self.assertEqual(self.days.loc["2026-03-01", "naps"], 0)


class StepsAndBodyTest(unittest.TestCase):
    def setUp(self):
        self.data = ippo.load(EXAMPLE, now=NOW)

    def test_steps_changed_in_place_and_deleted(self):
        steps = self.data.steps()
        self.assertEqual(list(steps["date"].dt.strftime("%Y-%m-%d")), ["2026-03-02"])
        self.assertEqual(steps.loc[0, "steps"], 6400)

    def test_profile_fields_are_replaced_one_by_one(self):
        profile = self.data.profile().iloc[0]
        self.assertEqual((profile["sex"], profile["birth_year"], profile["height_cm"]), ("female", 1990, 169))

    def test_a_changed_weight(self):
        self.assertEqual(self.data.weights().loc[0, "weight_kg"], 70.2)

    def test_the_limit_counts_from_its_day(self):
        daily = self.data.daily()
        self.assertTrue(pd.isna(daily.loc["2026-03-01", "energy_target_kcal"]))
        self.assertEqual(daily.loc["2026-03-03", "energy_target_kcal"], 1900)
        self.assertEqual(daily.loc["2026-03-02", "steps"], 6400)
        self.assertEqual(daily.loc["2026-03-01", "weight_kg"], 70.2)

    def test_foods_keep_vitamins_and_ingredients(self):
        foods = self.data.foods().set_index("name")
        milk = foods.loc["Fortified milk"]
        self.assertEqual(milk["vitamin_d_ug_per_100"], 1.1)
        self.assertEqual(milk["calcium_mg_per_100"], 120)
        self.assertEqual(milk["ingredients"], "Milk, vitamin D3.")


class NewNutrientsTest(unittest.TestCase):
    def test_a_nutrient_not_listed_yet_gets_its_own_column(self):
        events = ippo.load(EXAMPLE, now=NOW).events.copy()
        extra = events.iloc[[0]].copy()
        extra["module"] = "food"
        extra["type"] = "food_entry_recorded"
        extra["id"] = "019c0099-0000-7000-8000-000000000099"
        extra["data"] = [{"date": "2026-03-03", "name": "Yeast", "nutrients": {"energy_kcal": 20, "biotin_ug": 9}}]
        days = ippo.food.food_days(pd.concat([events, extra], ignore_index=True))
        self.assertEqual(days.loc["2026-03-03", "biotin_ug"], 9)
        self.assertTrue(pd.isna(days.loc["2026-03-01", "biotin_ug"]))


class DailyTest(unittest.TestCase):
    def setUp(self):
        self.data = ippo.load(EXAMPLE, now=NOW)

    def test_one_row_per_day_with_every_module(self):
        daily = self.data.daily()
        self.assertEqual(list(daily.index.strftime("%Y-%m-%d")), ["2026-03-01", "2026-03-02", "2026-03-03"])
        first = daily.loc["2026-03-01"]
        self.assertEqual((first["habits_done"], first["habits_logged"]), (1, 2))
        self.assertEqual(first["exercise_sets"], 4)
        self.assertEqual(first["energy_kcal"], 1040)
        # No food on 3 March: zero entries, but an unknown total.
        self.assertEqual(daily.loc["2026-03-03", "food_entries"], 0)
        self.assertTrue(pd.isna(daily.loc["2026-03-03", "energy_kcal"]))

    def test_csv_export_needs_nothing_to_read_back(self):
        with tempfile.TemporaryDirectory() as out:
            written = self.data.export_csv(out)
            self.assertEqual(len(written), len(ippo.data.TABLE_NAMES) + 1)
            sleep = pd.read_csv(Path(out) / "sleep_days.csv")
            self.assertEqual(sleep.loc[0, "date"], "2026-03-01")
            self.assertEqual(sleep.loc[0, "woke_up_utc"], "2026-03-01T06:00:00.000+00:00")
            self.assertEqual(sleep.loc[0, "woke_up_local"], "2026-03-01T07:00:00.000")
            events = pd.read_csv(Path(out) / "events.csv")
            self.assertEqual(len(events), 48)


class EmptyFolderTest(unittest.TestCase):
    def test_every_table_works_without_events(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / "events").mkdir()
            data = ippo.load(folder)
            for name in ippo.data.TABLE_NAMES:
                self.assertEqual(len(getattr(data, name)()), 0, name)
            self.assertIn("0 events", data.summary())


if __name__ == "__main__":
    unittest.main()
