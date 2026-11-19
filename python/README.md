# Ippo data in Python

A small package that turns an Ippo data folder into pandas tables, with
every change and deletion already applied, so you see the same thing as
the app. Its only dependency is pandas.

## Get your data onto your computer

Copy the whole data folder (the one holding `events/`) to your computer,
or let your sync tool do it. The app never needs to be running. The
`backups/` folder can stay behind: it only repeats what is in `events/`.

## Install

From this `python` folder:

```
pip install .
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
| `food_entries()` | thing eaten | Nutrients for the amount eaten. A missing nutrient is unknown, never zero. |
| `food_days()` | day | Totals, and `<nutrient>_complete`: whether every entry that day gave that nutrient. |
| `exercises()` | exercise | `measured_in` is `reps` or `seconds`. |
| `sets()` | set | `value` with `unit`, for every exercise. |
| `exercise_days()` | exercise and day | `sets`, `total`, `best`. |
| `steps()` | day | Steps walked. |
| `weights()` | day | Weight in kg. |
| `profile()` | one row | The latest sex, year of birth and height. |
| `energy_targets()` | limit set | The daily energy limit, from its `date` on (empty `energy_kcal`: no limit). |
| `sleep_days()` | day | Wake-up and bedtime (exact, local, and as hours), sleep before the day, time zone changes, naps. |
| `naps()` | nap | |
| `devices()` | device | When each device's data was last seen. |
| `events` | event | Everything, unprocessed, for anything the tables do not cover. |

Times come in two forms. `..._utc` columns are exact moments, right for
durations and ordering. `..._local` columns are the clock time where you
were, right for "what time do I go to bed?" across trips and daylight
saving. Hour columns such as `went_to_bed_h` count from that day's
midnight, so a bedtime of 01:00 the next morning is `25.0`.

Each docstring explains its table in detail: `help(ippo.food.food_days)`.

## Without Python

Write every table as a CSV file, for a spreadsheet or any other program:

```
python -m ippo export /path/to/data /path/to/csv-folder
```

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
