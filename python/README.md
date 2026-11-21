# Ippo data in Python

A small package that turns an Ippo data folder into pandas tables, with
every change and deletion already applied, so you see the same thing as
the app. Its only dependency is pandas (plus pyarrow, optionally, for
Parquet files).

Every column of every table is described in the codebook
(`ippo/codebook.py`): its type, its meaning, its unit as a
[UCUM](https://ucum.org) code, and, where one fits, its code in a
recognised vocabulary: INFOODS tagnames and USDA FoodData Central ids
for nutrients, LOINC for body weight and daily steps. The tables use
the codebook's types, so a column's dtype never depends on whether it
happens to hold values.

## Get your data onto your computer

Copy the whole data folder (the one holding `events/`) to your computer,
or let your sync tool do it. The app never needs to be running. The
`backups/` folder can stay behind: it only repeats what is in `events/`.

## Install

From this `python` folder:

```
pip install .
pip install ".[parquet]"    # also write Parquet files
```

Or skip installing: run Python from this folder, or add it to
`sys.path`, and `import ippo` works.

## Use

```python
import ippo

data = ippo.load("/path/to/data")
print(data.summary())       # what was loaded, and anything odd

daily = data.daily()        # one row per day, every module side by side
daily["sleep_before_h"].rolling(28).mean().plot()
```

| Method | One row per | Notes |
| --- | --- | --- |
| `daily()` | day | Habits done, food totals, sleep times, sets, steps, weight, the energy limit. Every calendar day is present, so gaps show. |
| `habits()` | habit | Including deleted ones (`deleted`). |
| `habit_entries()` | habit and day | The latest value counts. `True` done, `False` said no; no row means nothing recorded. |
| `habit_days()` | day | The habit grid: one column per habit. |
| `foods()` | food | Nutrients per 100 g or ml (vitamins and minerals too), the serving size, and the ingredients. |
| `food_entries()` | thing eaten | Nutrients for the amount eaten. A missing nutrient is unknown, never zero. When an entry gave only salt or only sodium, the other is worked out (salt = 2.5 × sodium). |
| `food_days()` | day | Totals; `<nutrient>_complete`: whether every entry that day gave that nutrient; `diary_complete`: the user's own mark that everything eaten that day is logged (empty if never marked). |
| `exercises()` | exercise | `measured_in` is `reps` or `seconds`. |
| `sets()` | set | `value` with `unit`, for every exercise. |
| `exercise_days()` | exercise and day | `sets`, `total`, `best`. |
| `steps()` | day | Steps walked. |
| `weights()` | day | Weight in kg. |
| `profile()` | one row | The latest sex, year of birth and height. |
| `energy_targets()` | limit set | The daily energy limit, from its `date` on (empty `energy_kcal`: no limit). |
| `nutrient_targets()` | goal set | The user's own amount a day of a nutrient (`nutrient`, `amount`, `kind`: `at_most` or `at_least`), from its `date` on, in place of the reference amount. |
| `sleep_days()` | day | Wake-up and bedtime (exact, local, and as hours), sleep before the day, time zone changes, naps. |
| `naps()` | nap | |
| `devices()` | device | When each device's data was last seen. |
| `events` | event | Everything, unprocessed, for anything the tables do not cover; with the `app_version` and `time_zone` (IANA name) each event was written with, when known. |
| `tables()` | | Every table above by name, as the export writes them. |

Times come in two forms. `..._utc` columns are exact moments, right for
durations and ordering. `..._local` columns are the clock time where you
were, right for "what time do I go to bed?" across trips and daylight
saving. Hour columns such as `went_to_bed_h` count from that day's
midnight, so a bedtime of 01:00 the next morning is `25.0`.

Each docstring explains its table in detail: `help(ippo.food.food_days)`.

## Export: for any other program

```
python -m ippo export /path/to/data /path/to/export-folder
```

or `data.export("/path/to/export-folder")` writes a folder that explains
itself:

| File | What |
| --- | --- |
| `<table>.csv` | Every table, one row per record; dates as `YYYY-MM-DD`, moments in UTC as `YYYY-MM-DDTHH:MM:SS.sss+00:00`. |
| `<table>.parquet` | The same tables in Apache Parquet, with each column's type kept (when pyarrow is installed; `--no-parquet` to skip). |
| `datapackage.json` | A [Frictionless Data Package](https://datapackage.org) (v2): every table and column with its type and description, and as extra properties its `unit` (UCUM) and `codes`. Frictionless tools validate and load it directly, in Python or R. |
| `codebook.csv` | The same descriptions as one table: `table`, `column`, `type`, `unit_ucum`, `description`, `infoods`, `usda_fdc_id`, `usda_fdc_number`, `loinc`. |
| `README.txt` | The rules that hold everywhere (empty means not recorded, never zero; what `date`, `_utc` and `_local` mean). |

`python -m ippo summary /path/to/data` prints what the folder holds.

## Try it without your own data

`examples/make_sample_data.py` makes four years of data for an invented
person, with the untidy parts of real use. `examples/overview.py` draws
charts from any data folder (it also needs matplotlib):

```
python examples/make_sample_data.py /tmp/ippo-sample
python examples/overview.py /tmp/ippo-sample /tmp/ippo-charts
```

## Writing your own reader

The format is described in full in `docs/data-format.md`. The folder
`example-data/` at the top of the repository is a small data folder
that holds every awkward case (conflict copies, a cut-off line, changes,
deletions, a bedtime after midnight, a time zone change). The tests in
`tests/` say exactly what a correct reader gets from it, so they double
as a checklist for a reader in another language.

## Tests

```
python -m unittest
```
