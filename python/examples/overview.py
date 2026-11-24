# SPDX-License-Identifier: GPL-3.0-or-later
"""Charts of a whole data folder: a starting point for your own analyses.

Usage (needs matplotlib as well as pandas):

    python overview.py /path/to/data /path/to/charts

Writes four PNG files: trends over time, bed and wake-up times, a habit
calendar for the last year, and how sleep relates to the next day.
"""

import sys
from pathlib import Path

try:
    import matplotlib
    import pandas  # noqa: F401  (only checked here; ippo uses it)
except ImportError as missing:
    sys.exit(
        f"This example needs {missing.name}, which this Python does not have.\n"
        "Use a separate environment rather than the system Python, for example:\n"
        "  conda create -n ippo python=3.12 pandas matplotlib\n"
        "  conda activate ippo"
    )

matplotlib.use("Agg")  # write files; no window needed
import matplotlib.pyplot as plt  # noqa: E402  (must come after use())

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # find ippo without installing
import ippo  # noqa: E402

data = ippo.load(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
print(data.summary())

daily = data.daily()


def monthly(series):
    """A 28-day rolling mean: smooth enough to show trends."""
    return series.rolling(28, min_periods=14).mean()


# 1. Trends over the years ----------------------------------------------------
figure, axes = plt.subplots(4, 1, figsize=(11, 12), sharex=True)

axes[0].plot(daily.index, daily["energy_kcal"], color="#ccc", linewidth=0.5)
axes[0].plot(daily.index, monthly(daily["energy_kcal"]), linewidth=2)
axes[0].set_title("Energy eaten (kcal per day, 28-day mean)")

# Nights across a time zone change are real elapsed time, which would
# look like very short or very long sleep; leave them out here.
sleep = daily["sleep_before_h"].where(daily["time_zone_changed"] != True)  # noqa: E712
axes[1].plot(daily.index, sleep, color="#ccc", linewidth=0.5)
axes[1].plot(daily.index, monthly(sleep), linewidth=2)
axes[1].set_title("Sleep before each day (hours)")

exercise = data.exercise_days()
for name, sessions in exercise[exercise["unit"] == "reps"].groupby("exercise"):
    sessions = sessions.set_index("date")["best"]
    axes[2].scatter(sessions.index, sessions, s=4, alpha=0.3)
    axes[2].plot(sessions.index, sessions.rolling(12, min_periods=4).mean(), linewidth=2, label=name)
axes[2].set_title("Best set per session (reps)")
axes[2].legend(frameon=False)

grid = data.habit_days()
for habit in grid.columns:
    done = grid[habit].eq(True).astype(float).where(grid[habit].notna())
    axes[3].plot(grid.index, done.rolling(56, min_periods=20).mean() * 100, linewidth=2, label=habit)
axes[3].set_title("Habits: % of logged days done (8-week mean)")
axes[3].legend(frameon=False, ncol=3)
figure.tight_layout()
figure.savefig(out / "1_trends.png", dpi=110)

# 2. Bed and wake-up times on the local clock ---------------------------------
# went_to_bed_h counts past midnight (01:00 is 25), so it averages sensibly.
figure, axis = plt.subplots(figsize=(11, 4))
for column, label in [("went_to_bed_h", "went to bed"), ("woke_up_h", "woke up (drawn 24 h later)")]:
    hours = daily[column] + (24 if column == "woke_up_h" else 0)
    axis.scatter(daily.index, hours, s=3, alpha=0.3)
    axis.plot(daily.index, monthly(hours), linewidth=2, label=label)
axis.set_yticks(range(21, 35))
axis.set_yticklabels([f"{hour % 24:02d}:00" for hour in range(21, 35)])
axis.set_title("Bedtime and wake-up, local clock time")
axis.legend(frameon=False)
figure.tight_layout()
figure.savefig(out / "2_bed_and_wake.png", dpi=110)

# 3. A habit calendar: done, said no, nothing recorded -------------------------
habit = grid.columns[0]
last_year = grid[habit].iloc[-364:]
codes = last_year.map({True: 2, False: 1}).fillna(0).astype(float)
weeks = codes.groupby(last_year.index.to_period("W")).apply(
    lambda week: week.set_axis(week.index.weekday).reindex(range(7))
).unstack().T
figure, axis = plt.subplots(figsize=(11, 2.4))
colors = matplotlib.colors.ListedColormap(["#e9ecef", "#ffa8a8", "#2f9e44"])
axis.imshow(weeks, aspect="auto", cmap=colors, vmin=0, vmax=2)
axis.set_yticks(range(7), ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
axis.set_xticks([])
axis.set_title(f'"{habit}", last year: green done, red said no, gray nothing recorded')
figure.tight_layout()
figure.savefig(out / "3_habit_calendar.png", dpi=110)

# 4. Does a short night change the next day? ---------------------------------
night = daily["sleep_before_h"].where(daily["time_zone_changed"] == False)  # noqa: E712
short = night < 7
habit_rate = daily["habits_done"] / daily["habits_marked"]
figure, axes = plt.subplots(1, 3, figsize=(12, 3.6))
for axis, values, title in [
    (axes[0], habit_rate * 100, "Habits done (%)"),
    (axes[1], daily["energy_kcal"], "Energy eaten (kcal)"),
]:
    means = [values[~short & night.notna()].mean(), values[short].mean()]
    axis.bar(["7 h or more", "under 7 h"], means)
    axis.set_ylim(min(means) * 0.9, max(means) * 1.03)
    axis.set_title(f"{title}\nafter a night of ...")
weekday = daily.groupby(daily.index.weekday)["energy_kcal"].mean()
axes[2].bar(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], weekday)
axes[2].set_ylim(weekday.min() * 0.9, weekday.max() * 1.03)
axes[2].set_title("Energy eaten by weekday (kcal)")
figure.tight_layout()
figure.savefig(out / "4_relationships.png", dpi=110)
print(f"Charts written to {out}")
