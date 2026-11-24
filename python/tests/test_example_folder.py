# SPDX-License-Identifier: GPL-3.0-or-later
"""Tests against the example data folder at the top of the repository.

The folder holds every awkward case on purpose: a sync conflict copy, a
hidden file, a cut-off line, a backup, changes, deletions, a bedtime
after midnight and a time zone change. The app's own tests
(``test/example_data_test.dart``) check the same answers, so the app
and this package are known to agree.

Run from the ``python`` folder with: ``python -m unittest``
"""

import json
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
        self.assertEqual(len(self.data.events), 52)
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
        self.assertEqual(devices.loc["my-phone", "events"], 49)
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
        self.assertEqual((first["habits_done"], first["habits_marked"]), (1, 2))
        self.assertTrue(first["habits_logged"] and first["food_logged"] and first["any_logged"])
        self.assertEqual(first["exercise_sets"], 4)
        self.assertEqual(first["energy_kcal"], 1040)
        # No food on 3 March: not logged, so the count and the total are
        # unknown (empty), never 0.
        self.assertFalse(daily.loc["2026-03-03", "food_logged"])
        self.assertTrue(pd.isna(daily.loc["2026-03-03", "food_entries"]))
        self.assertTrue(pd.isna(daily.loc["2026-03-03", "energy_kcal"]))

    def test_export_needs_nothing_to_read_back(self):
        with tempfile.TemporaryDirectory() as out:
            written = self.data.export(out, parquet=False)
            names = {path.name for path in written}
            for table in [*ippo.data.TABLE_NAMES, "events"]:
                self.assertIn(f"{table}.csv", names)
            self.assertTrue({"datapackage.json", "codebook.csv", "README.txt"} <= names)
            sleep = pd.read_csv(Path(out) / "sleep_days.csv")
            self.assertEqual(sleep.loc[0, "date"], "2026-03-01")
            self.assertEqual(sleep.loc[0, "woke_up_utc"], "2026-03-01T06:00:00.000+00:00")
            self.assertEqual(sleep.loc[0, "woke_up_local"], "2026-03-01T07:00:00.000")
            events = pd.read_csv(Path(out) / "events.csv")
            self.assertEqual(len(events), 52)

    def test_data_package_describes_every_column_of_every_file(self):
        with tempfile.TemporaryDirectory() as out:
            self.data.export(out, parquet=False)
            package = json.loads((Path(out) / "datapackage.json").read_text(encoding="utf-8"))
            self.assertEqual(package["$schema"], "https://datapackage.org/profiles/2.0/datapackage.json")
            for resource in package["resources"]:
                header = list(pd.read_csv(Path(out) / resource["path"], nrows=0).columns)
                fields = resource["schema"]["fields"]
                self.assertEqual([field["name"] for field in fields], header, resource["path"])
                for field in fields:
                    self.assertNotEqual(field["description"], "Not described in the codebook.",
                                        f"{resource['path']}: {field['name']}")
            weights = next(r for r in package["resources"] if r["name"] == "weights")
            weight = next(f for f in weights["schema"]["fields"] if f["name"] == "weight_kg")
            self.assertEqual((weight["unit"], weight["codes"]["loinc"]), ("kg", "29463-7"))
            codebook = pd.read_csv(Path(out) / "codebook.csv")
            rows = codebook[(codebook["table"] == "food_entries") & (codebook["column"] == "proteins_g")]
            protein = rows.iloc[0]
            codes = (protein["infoods"], protein["usda_fdc_id"], protein["unit_ucum"])
            self.assertEqual(codes, ("PROCNT", 1003, "g"))

    @unittest.skipUnless(ippo.export.parquet_available(), "pyarrow is not installed")
    def test_parquet_keeps_the_column_types(self):
        with tempfile.TemporaryDirectory() as out:
            self.data.export(out, parquet=True)
            days = pd.read_parquet(Path(out) / "food_days.parquet")
            self.assertEqual(str(days["diary_complete"].dtype), "boolean")
            self.assertEqual(str(days["food_entries"].dtype), "Int64")


class SaltAndSodiumTest(unittest.TestCase):
    def test_either_one_gives_the_other(self):
        events = pd.DataFrame([
            _food_entry("019c1000-0000-7000-8000-000000000001", {"energy_kcal": 100, "salt_g": 1.5}),
            _food_entry("019c1000-0000-7000-8000-000000000002", {"energy_kcal": 100, "sodium_mg": 400}),
        ])
        entries = ippo.food.food_entries(events)
        self.assertEqual(list(entries["sodium_mg"]), [600, 400])
        self.assertEqual(list(entries["salt_g"]), [1.5, 1.0])
        day = ippo.food.food_days(events).iloc[0]
        self.assertEqual((day["salt_g"], day["sodium_mg"]), (2.5, 1000))
        self.assertTrue(day["sodium_mg_complete"])


def _food_entry(event_id, nutrients):
    """A food_entry_recorded event as the events table holds it."""
    moment = pd.Timestamp("2026-03-01T12:00:00Z")
    return {
        "id": event_id, "module": "food", "type": "food_entry_recorded", "recorded_utc": moment,
        "data": {"date": "2026-03-01", "name": "Soup", "nutrients": nutrients},
    }


class DiaryAndProvenanceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = ippo.load(EXAMPLE, now=NOW)

    def test_the_latest_mark_of_a_day_counts(self):
        days = self.data.food_days()
        self.assertTrue(days.loc["2026-03-01", "diary_complete"])
        self.assertFalse(days.loc["2026-03-02", "diary_complete"])
        self.assertTrue(pd.isna(self.data.daily().loc["2026-03-03", "diary_complete"]))

    def test_nutrient_goals_say_their_nutrient_amount_and_kind(self):
        goal = self.data.nutrient_targets().iloc[0]
        self.assertEqual((goal["nutrient"], goal["amount"], goal["kind"]), ("fat_g", 60, "at_most"))
        self.assertEqual(goal["date"], day("2026-03-02"))

    def test_events_keep_the_app_version_and_time_zone_when_given(self):
        events = self.data.events.set_index("id")
        marked = events.loc["019c0040-0000-7000-8000-000000000040"]
        self.assertEqual((marked["app_version"], marked["time_zone"]), ("0.1.0", "America/New_York"))
        self.assertTrue(pd.isna(events.iloc[0]["time_zone"]))


class LoggingActivityTest(unittest.TestCase):
    def test_each_day_and_module_says_when_it_was_logged(self):
        activity = ippo.load(EXAMPLE, now=NOW).logging_activity().set_index(["date", "module"])
        modules = set(activity.index.get_level_values("module"))
        self.assertEqual(modules, {"body", "exercise", "food", "habits", "sleep"})
        # Habits on 1 March were marked the same day; those of 3 March the
        # day after; the weight of 1 March was typed in three days later.
        self.assertEqual(activity.loc[(day("2026-03-01"), "habits"), "first_logged_days_after"], 0)
        self.assertEqual(activity.loc[(day("2026-03-03"), "habits"), "first_logged_days_after"], 1)
        self.assertEqual(activity.loc[(day("2026-03-01"), "body"), "first_logged_days_after"], 3)
        food = activity.loc[(day("2026-03-01"), "food")]
        self.assertGreaterEqual(food["events"], 2)
        self.assertLessEqual(food["first_recorded_utc"], food["last_recorded_utc"])


class CodebookTest(unittest.TestCase):
    def test_every_column_of_every_table_is_described(self):
        data = ippo.load(EXAMPLE, now=NOW)
        for name, frame in data.tables().items():
            for column in [*frame.columns, *([frame.index.name] if frame.index.name else [])]:
                self.assertIsNotNone(ippo.codebook.describe(name, column), f"{name}.{column}")

    def test_every_type_and_unit_is_from_the_standards_used(self):
        types = {"string", "integer", "number", "boolean", "date", "datetime", "any"}
        units = {"", "kg", "cm", "g", "mg", "ug", "kcal", "h", "{steps}/d"}
        for table in ippo.codebook.TABLES.values():
            for column in table.values():
                self.assertIn(column.type, types, column.name)
                self.assertIn(column.unit, units, column.name)


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
