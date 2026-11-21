# Ippo design guide

This guide describes how every screen in Ippo looks and behaves, so the
app feels like one thing and stays quick to use. Follow it for every new
screen and module. If a rule gets in the way, change it here first, then
change every screen to match.

- The building blocks are in `lib/core/widgets/section_card.dart`, the
  theme in `lib/core/theme.dart`. Use them; do not style by hand.
- **The Sleep screen is the reference.** When unsure, make a screen
  look and work like Sleep.

Contents:

1. [Principles](#1-principles)
2. [Screen structure](#2-screen-structure)
3. [Fields, information and buttons](#3-fields-information-and-buttons)
4. [Where actions go](#4-where-actions-go)
5. [Lists](#5-lists)
6. [Text and wording](#6-text-and-wording)
7. [Numbers, times and units](#7-numbers-times-and-units)
8. [Icons](#8-icons)
9. [Colour](#9-colour)
10. [Spacing and sizes](#10-spacing-and-sizes)
11. [Feedback: saving, errors, undo](#11-feedback-saving-errors-undo)
12. [Empty, loading and problem states](#12-empty-loading-and-problem-states)
13. [Accessibility](#13-accessibility)
14. [Template for a new module screen](#14-template-for-a-new-module-screen)
15. [Checklist](#15-checklist)


## 1. Principles

1. **Logging is fast.** The everyday entry takes one or two taps on the
   module's own screen. Fields start with sensible values: last night's
   bedtime, the last set's reps, the current time.
2. **Only what is needed.** No decoration or quotes. Statistics live
   in one place, the Charts screen (section 2), not on the logging
   screens. Deeper analysis happens outside the app, on the plain data
   files.
3. **Obvious at a glance.** Anyone can tell what can be changed, what is
   only information, and what does something (see section 3).
4. **The same everywhere.** The same kind of thing looks and sits the
   same on every screen.
5. **Nothing is lost.** Deleting offers Undo. Errors are shown, never
   hidden.


## 2. Screen structure

### The app frame

- A bar along the bottom with one tab per screen: **Home**, then each
  module in `lib/modules/all_modules.dart`. Android recommends at most
  five tabs, so **Settings is not a tab**: it opens from a gear at the
  top right of Home.
- The app opens on Home. Without a data folder, every tab shows a short
  welcome with a button leading to Settings.
- Each tab keeps its state (the day shown, typed numbers) while another
  tab is open.
- On a wide window (840 dp or more: the Linux desktop, a tablet on its
  side), the tabs go down the left side (`NavigationRail`) and screens
  keep a readable width of at most 720.
- The app draws behind a see-through system navigation bar, so its own
  colours reach the bottom edge.

### A module screen, top to bottom

1. **Top bar** (`SkyAppBar`) on a band of the Home sky (its birds by
   day, its stars and shooting star by night; no sun, moon or land),
   fading into the page, with the module's name ("Sleep") on the left
   and, if the screen shows one day, the day picker (`DayBar`:
   ‹ 📅 Today › ») on the right, in `AppBar.actions`. The day is the
   same on every tab (kept in `AppState`). On any day but today, the day
   is shown in a tinted pill, because logging to the wrong day is easy
   to miss; » goes straight back to today. › and » are greyed out on
   today, and nothing in the bar moves as the day changes: the day has
   a fixed width. There is no day after today: no data can be there.
2. **Cards** (`SectionCard`), one per section, each starting with a
   `CardHeader`.
3. **Create buttons** in the page, just above the list they add to, in
   one row: the usual one (**+ Add food**, **+ New exercise**, **+ New
   habit**) tonal in the right half, a second one (**Quick food**)
   outlined in the left half (section 4). The module tabs have no
   floating buttons: they took too much room and covered the list.

Nothing sits outside a card except short notes or problems at the top.

### Home

Home is **information**, like a weather app: a quick glance at what
matters about the day so far. The bar at the bottom leads to the
modules; on Home, the chart button (Charts), the Settings gear and
the day bar can be tapped (the
day bar looks back at earlier days: "Looking back" replaces the
greeting, and times since become clock times), a tile opens its tab, a day in the week grid shows that day, and the
Lately card opens Charts.

At the top, a landscape (`SkyHeader`) under a sky that follows the time
of day (dawn with a low sun and mist, a blue day with a few birds, dusk
with the moon rising, night with stars and now and then a shooting
star), fading into the page. The landscape is seen from a forested
valley, made up fresh each day from the date: a tall, continuous range
of bare rock with snow only on its tops (broad massifs with a few
summits, each shaded on the face turned from the sun or moon), rising
straight out of the valley with haze at its foot; a farther range
behind it, paler with the distance; a long line of spruce forest on the
valley floor; and a few tall spruces close by. (The launcher icon
is its own drawing in the same night colours: steps climbing toward
the rising moon.) So Home looks a
little different every day, and the same all day long. The
greeting and the gear sit on its sky, which is kept clear above the
mountains. It is decoration: screen readers skip it.

The greeting ("Good afternoon") and the gear sit on its sky; the date
("Wednesday, 18 Nov") and the day bar sit on the ground at its foot.
Then the **week grid**, and under it **one tile per module** in a grid,
two per row (one per row with large text, up to four on a wide
window), each row as tall as its tallest tile. Everything fits on one
phone screen, so Home is a glance, not a scroll. Two notes appear only
when needed: for someone who has logged nothing yet ("Log things in
the tabs below."), and when another device has not synced for more
than a day.

The page follows the way Apple's Weather app makes numbers easy to
read: one tile per subject, every tile built the same way, and **no
number without its context**. Today's value is large; the usual is
always in a row of its own with a plain label ("Avg (7 days)"),
never left for the reader to guess.

**Anyone must understand it without asking.** Imagine someone who has
never opened the app: every label says plainly what its number is,
every picture is explained on the spot (Lately says in a sentence
what its two columns are), and nothing is shown just because it can
be. A number that needs explaining, or that does not help decide
anything today, does not belong on Home.

- **The week grid** ("Last 7 days", `WeekGrid`): the days across the
  top, the day shown in the accent colour with a soft column behind
  it, and one row per module, named with
  its unit on the left ("Habits (%)", "Food (kcal)", "Exercises",
  "Steps (k)", "Sleep (h)"), with one short value per day, like a small
  table (`IppoModule.weekRows`). A day without data shows a quiet dash.
  A module without any data yet has no row. Tapping a day shows it;
  the seven days stay put while the day shown is one of them.
- **Lately** (`LatelyCard`), at the bottom: one row per measure
  (`IppoModule.trendMeasures`): the average of the 7 days before the
  day shown (not the day itself, which is not over: half a day would
  pull every average down; so these match the tiles' "Avg (7 days)"),
  your usual (the 28 days before those), and an arrow for which way it
  moved, never coloured, since up or down is not good or bad in itself.
  Only days with something logged count, so a gap never looks like a
  zero; the usual waits for 7 days of data, and a change within 5 % (1 %
  for weight, which moves slowly) is shown as steady. A last line says on how many of those 35 days anything was
  logged, since gaps make a week say less. It replaced a "days logged"
  calendar, which looked the same every day for anyone logging daily.
- **One tile per module** (`IppoModule.homeTile`, drawn by
  `HomeTileCard`). Every tile has the same four parts, in the same
  places, so tiles side by side line up:
  1. the header: the module's icon in the accent colour and its title
     in small grey capitals ("FOOD");
  2. **today's value**, large (digits large, units small and grey:
     `ValueText`), with a word after it that says what it is: "4 of 8
     done", "1267 kcal of 2000", "6,390 steps", "7 h 8 min slept";
  3. **one mark**, in a row of fixed height: one dot per habit in its
     own colour; protein, carbs and fat with bars against their daily
     amounts (red past them); a badge for the day's workout ("4
     exercises today" or "Rest day"); last night as one bar from
     bedtime to waking up. With nothing logged, a short note takes its
     place, saying exactly what is missing ("Bedtime not logged");
  4. **one or two rows** (`TileRow`): a grey label at the left and its
     number at the right edge, so numbers line up down a tile and
     across a row of tiles: "Best streak 30 days", "Left today 733
     kcal" (or "Over the limit", in red), "Awake for 8 h 52 min", then
     the usual, last: "Avg (7 days)", "Avg (7 nights)".
     Never loose sentences.
- **The usual** is the 7 days before the day shown, not counting days
  with nothing logged (a day not logged is not a day without food).
  The day shown is left out: it is usually not over yet.
- Every tile must earn its place: something a person wants to know at
  a glance and can act on. Totals that mix unlike things (all reps of
  all exercises) do not; steps, a streak, calories left do. A mark
  must work with any number of things, and fill the tile's width like
  the others: the habits bar has one segment per habit, which get
  narrower as habits are added.
- Facts are **never joined into one line** with "·" or commas.
- Durations ago are rounded for a glance: "25 min ago", then whole
  hours, "8 h ago". Home redraws every minute so they stay current.
- Screen readers read a tile as one item.

### Charts

Every measure over time, on one screen opened from Home (the chart
button beside the gear, or tapping Lately). It is not a tab: Android
recommends at most five, and Home and the modules already use them.

The charts are meant to be read like figures in a paper, on a phone:

- **An index first, so a chart is quick to find.** Charts lists one
  card per module (in the order of `allModules`), with one row per
  chart: its name and unit, its change per week over the last 30 days,
  a small line of those days (`ChartSparkline`), and its latest 7-day
  mean, labelled. Tapping a row opens the chart on a screen of its own
  (`ChartScreen`). A module offers its charts with `IppoModule.charts`,
  as `ChartSpec`s: one value per day logged, and optionally a limit, a
  recommended band or spans (bedtime to waking up). The core draws them
  all the same way (`lib/core/charts/`), so a new chart is a few lines
  in its module.
- **Any days.** A chart's screen has the usual periods (Week, Month,
  3 mo, Year, All, each ending today) and under them the days shown, as
  a button that opens a calendar to pick any first and last day, with
  ‹ › to step back and forward by as many days. › stops at today. A
  period reaching back before anything was logged starts at the first
  day logged instead.
- **The raw values faint, the running mean strong.** Dots for
  measurements (weight, best set), bars from zero for amounts (energy,
  steps). The line is the mean of the values in the 7 days ending each
  logged day (28 days once a chart spans more than four months), worked
  out only on logged days and broken across gaps as long as the window.
  A missing day is never a zero.
- **Axes like graph paper**: round numbers (1, 2, 2.5 or 5 times a power
  of ten; hours by 1, 2, 3 or 6; counts never by less than 1), light
  grid lines, dates as Mondays, months or years. Measurements zoom in
  on their values, so a change of a kilogram shows; bars start at zero,
  so a bar's length is its value.
- **Four numbers sum up the period**, labelled: Mean, SD (the sample
  standard deviation), Per week (the slope of the least-squares line,
  only with 3 values over 7 days or more), and how many values. Tapping
  or dragging across a plot reads out one day in their place.
- **Today's running totals** (food, steps, habits) are drawn fainter,
  named "Today so far", and left out of the mean and the summary, as
  on Home.
- **Every mark is in the legend**, and a band from a published source
  names it in a note under the chart (sleep: 7–9 h, Hirshkowitz et al.,
  2015).
- Accent colour and theme greys only, never colour alone: every mark
  differs in shape too (dot, bar, line, dashes, band).

### Daily amounts and the calorie limit

Numbers about food are shown **against what is normal for a day**, so
they mean something: a thin bar under each nutrient fills up to its
daily reference amount ("73 g of 50 g"), on the Food page and on Home.
The amounts are the EU's reference intakes for an adult (scaled to the
user's calorie limit, with protein by body weight when known); see
`lib/modules/food/daily_references.dart` for every source. They are
averages for adults, never presented as targets. The Food page's
**All nutrients** opens every other nutrient of the day the same way.

The calorie limit is set on the **Body and calories** screen, reached
from the Food page's Total card and from Settings: sex, year of birth
and height, weight logged over time, and from them the BMR
(Mifflin-St Jeor) with the energy used at each activity level, which
help choose a limit. A new limit counts from the day it is set.

**Every formula is open.** An ⓘ on the Body screen opens "How these are
worked out" (`SourcesScreen`): each number Ippo works out, its formula
typeset in LaTeX, what each letter means, why that formula, and full
citations. A rule of thumb is called one.

Body measurements are shown in **metric or imperial** units (Settings,
metric by default; `units.dart`); the data is always metric. Food
amounts stay in grams and millilitres, as on labels everywhere.

### Forms (adding or changing one thing)

A screen of its own, like Material's full-screen dialog: the top bar
has ✕ on the left (close without saving), the thing's name ("Nap",
"New food"), and **Save** on the right (`AppBarSaveButton`). Save stays
in reach however long the form is. Below: the fields, then any
information (such as "8 h of sleep"), then a red **Delete** button at
the very end when changing an existing thing.

Long forms are split into short cards in the order a person thinks
about the thing (for a food: name, serving size, nutrition). Fields
most people skip stay closed behind a "More …" link that opens
smoothly (`AnimatedSize`), and open by themselves when they hold
values. Number fields use the keyboard's **Next** key
(`TextInputAction.next`) to move on to the next field; only the last
field's Done acts.

Leaving a form with unsaved changes (✕, back button or back gesture)
asks "Discard changes?" first (`DiscardGuard`); a form without changes
closes at once. The ✕ calls `Navigator.maybePop`, so it goes through
the guard too.


## 3. Fields, information and buttons

Every element is exactly one of these kinds, and each kind always looks
the same:

| Kind | Looks like | Use |
| --- | --- | --- |
| **Editable** | An outlined box with a label on its border | `TextField` (the theme adds the outline), `TimeField` for times, `DateTimeField` when the date matters too |
| **Information** | Plain text: a small grey label above a larger value | `InfoValue`, or `InfoRow` for several side by side; `InfoText` for long text such as paths; `HomeTileCard` on Home |
| **Note** | Plain grey text | `NoteText`, for short notes and empty states |
| **Problem** | Plain red text that says what is wrong | `ProblemText` |
| **Action** | A button: filled, text, or floating | See section 4 |

Rules:

- Information never has a border, background or chevron, so it never
  looks tappable.
- Fields that belong together sit **side by side at equal width** with a
  plain 12-pixel gap. No symbols between them: no "×", "→" or "–".
- When a time can fall on a different calendar day (going to bed after
  midnight), use a `DateTimeField`, so the date is chosen and shown
  rather than guessed.
- A field that has nothing yet shows "Not set". Saving skips it, so the
  data never holds a value nobody entered.
- A value that is **only a suggestion** (the usual wake-up time) is shown
  grey and marked "Suggested", so it is never mistaken for a saved one.
- Tapping a `DateTimeField` opens the **clock** straight away and works
  out the date; its calendar button changes the date, which is rarely
  needed.
- A field's label says what goes in it ("Went to bed", "Reps"). Add a
  unit as a suffix inside the field ("kg", "g"). Labels always sit on
  the border, so units and examples show before anything is typed.
- Mark nothing as "(optional)". When most fields are optional, the one
  that is required says so when it is missing.
- One word for one thing everywhere: Energy, Protein, Carbs, Fat.
- A setting that cannot be changed any more is shown as **information**
  with a note saying why, never as a greyed-out control.
- Choices between a few options use a `SegmentedButton` filling the
  card's width (`expandedInsets: EdgeInsets.zero`), never a dropdown, so
  every option is visible.
- A control that is not a text field (a choice, a row of colours) gets
  a small grey `FieldLabel` above it ("Theme", "Accent colour").
- Settings that change rarely (a device's name) are shown as
  information with an **Edit** button in the header, which opens a
  small window with the field. They do not sit on screen as open text
  fields.


## 4. Where actions go

| Action | Where | Looks like | Examples |
| --- | --- | --- | --- |
| Create something on a module tab | In the page, just above the list it adds to; one row, right half for the usual one, left half for a second | Tonal button (usual) and outlined button (second), icon and a short label | **+ Add food** with **Quick food**, **+ New exercise**, **+ New habit** |
| Create something on a list screen (not a tab) | Bottom right | Extended floating button: icon and a short label | **+ New food** (Add food, Your foods) |
| An action for one card | Right side of the card's header | Text button with icon: `HeaderAddButton`, `HeaderEditButton` | **+ Add** (naps), **Edit** (a logged night), **Refresh** |
| Change one row of a list | The whole row | `ListTile` with `onTap` | a food entry, a nap |
| Pick from a list (a chooser) | The whole row; changing the thing itself is on the next screen | `ListTile` with `onTap` | a food in "Add food" |
| Save a form screen | Right of the top bar | `AppBarSaveButton` | **Save** (New food, Nap) |
| Save on a module's own screen (not a form) | Bottom of its card, full width | Filled button | **Save** (Sleep's day card) |
| Delete | Under the Save button | Red text button: `DeleteButton` | **Delete this nap** |

- At most **one filled button** is in view on a card or form, so the
  main action is obvious. An action repeated on every card (an exercise's
  **Add**) is **tonal** (`FilledButton.tonal`), and the second of two
  create buttons is the quieter (outlined) one, so accent colour stays
  scarce.
- A Save on a module's own screen says **Saved** (disabled, with a ✓)
  when nothing is waiting to be saved, which also confirms that saving
  worked.
- Every floating button has its own `heroTag`: Flutter cannot animate
  two floating buttons with the same tag (opening another screen would
  fail).
- A card header has **at most one** action.
- On a screen with a floating button, leave room at the bottom so it
  never covers the last row (96 pixels).


## 5. Lists

- Each row has a **title** (the thing: "Cheezits", "14:00 – 14:45") and
  a **subtitle** with details: time first, then amount, side by side
  with a gap, never joined by "·". Leave out what is not known.
- **The number people scan goes on the right** (`trailing`), in one
  column: "280 kcal".
- Rows are in the order things happened.
- Numbers that only make sense side by side, such as the sets of an
  exercise, go in a **small table that names every row and column**:
  a column per set ("Set 1", "Set 2"), the unit in the corner ("reps"),
  a row for the day shown, and the last session under it in grey, so
  it is plain what each number is and whether the day went better.
  Tapping a number of the day shown opens it for changing.


## 6. Text and wording

- **Sentence case** everywhere: "Went to bed", "New exercise", not "Went
  To Bed".
- **Plain, everyday words.** "Went to bed", not "sleep onset"; "Nothing
  logged today", not "No data".
- **Buttons say what they do**, with a verb when it helps: "Save night",
  "Add", "Choose folder", "Delete this entry".
- **Notes are full sentences** with a full stop: "No naps on this day."
- **Problems say what to do**: "Please enter a whole number."
- **No exclamation marks, jokes or emoji.**

Text styles (from the theme's text styles):

| Use | Style |
| --- | --- |
| Home greeting | `headlineSmall` |
| Home tile values | `headlineSmall` digits, `labelLarge` grey units and note (set by `HomeTileCard` with `ValueText`) |
| Home tile lines | `bodySmall`, grey; labels above numbers `labelSmall`, grey |
| Home tile titles | `labelSmall` capitals, grey (set by `HomeTileCard`) |
| Home date | `titleMedium`, grey (`onSurfaceVariant`) |
| Card titles | `titleMedium` (set by `CardHeader`) |
| Information values | `titleMedium` (set by `InfoValue`) |
| Information labels | `labelMedium`, grey (set by `InfoValue`) |
| Notes | `bodyMedium`, grey (set by `NoteText`) |
| Small print (device id) | `bodySmall`, grey (`InfoText` with `isSmallPrint`) |

Every style uses digits of equal width (set once in `buildTheme`), so
numbers line up in columns and values that change do not shift.


## 7. Numbers, times and units

| Kind | Format | Examples |
| --- | --- | --- |
| Times of day | 24-hour `HH:MM` | `07:00`, `23:30` |
| Durations | Hours and minutes, no zeros | `7 h 30 min`, `8 h`, `45 min` |
| Time since | Duration and "ago" | `3 h 15 min ago`, `Just now` |
| Dates in lists | `YYYY-MM-DD` | `2026-11-18` |
| Days in the day bar | `Today`, `Yesterday`, else weekday and date | `Mon 16 Nov` |
| A date and time in a field | Short date above the time | `Thu 19 Nov` / `01:00` |
| Amounts | No needless decimals, at most one | `150`, `12.5` |
| Energy | Number, space, `kcal` | `200 kcal` |
| Weights and nutrients | Number, space, unit | `5 g`, `10 kg` |
| Unknown values | An en dash | `–` |

Use `formatAmount`, `formatDuration`, `formatTimeAgo`,
`formatTimeOfDay` and `describeDay` rather than formatting by hand.
Pickers use British English, so they match: weeks start on Monday and
the clock has 24 hours.

**When a day starts.** A day lasts until 05:00 the next morning
(`dayStartHour`), in every module: a snack at 01:00 or going to bed at
02:00 counts for the evening you were still awake in. Use `today()` or
`currentDay(now)`, never the calendar date of `DateTime.now()`. Screens
that show a day mix in `FollowsToday`, so they move on to the new day
by themselves unless the user picked another day.


## 8. Icons

- **Material icons that show a thing**: a fork and knife for food, a
  moon for sleep, a dumbbell for exercise.
- **No symbols, letters or emoji-like icons** (no Σ, no smileys).
- **One icon per meaning, everywhere.** Current icons:

| Meaning | Icon |
| --- | --- |
| Home | `home` (outlined when not selected) |
| Habits | `check_circle_outline` |
| Done / not done (habit grid) | `check` / `close` |
| Covered by the habit's frequency (habit grid) | a small dot in the habit's colour (`CoveredMark`), on any day not done (✗ or nothing marked) where every stretch of the habit's period through it was kept: the chain held. It comes from the days around it, so a tap cannot remove it; tapping it gives ✓. "Every other day" with ✓ Monday and ✓ Wednesday covers Tuesday; with ✗ Wednesday too, the chain broke and neither is covered |
| Food, food eaten | `restaurant` |
| Food totals (energy) | `local_fire_department` |
| Your foods (a list) | `list_alt` |
| Quick food | `bolt` |
| Exercise | `DumbbellIcon`, drawn: a level dumbbell with thick plates (`IppoModule.buildIcon`) |
| Sleep, a night | `MoonIcon`, drawn: a full, even crescent with a small star (`IppoModule.buildIcon`) |
| A nap | `airline_seat_flat` |
| Settings | `settings_outlined` (the gear on Home) |
| Add, new | `add` |
| Change one thing | `edit_outlined` |
| A time field | `schedule` |
| Data folder | `folder`, `folder_open` to choose one |
| Appearance | `palette` |
| This device | `smartphone` |
| Other devices | `devices`, `devices_other` |
| Read again | `refresh` |
| Charts | `show_chart` (the button on Home) |
| Weight | `monitor_weight_outlined` |

Card headers show their icon in the accent colour. Home tiles use their
module's icon, so a glance says which tab a tile belongs to.


## 9. Colour

1. **The phone's colours by default.** On Android 12 and later, Ippo
   uses the phone's system accent colour, so it matches the rest of the
   phone. Users can pick another in Settings > Appearance.
2. **One accent shade.** Every accent-coloured part (filled buttons,
   floating buttons, header icons, text buttons) uses the same main
   colour. Highlights (the selected tab or option) use a light tint of
   it. `buildTheme` enforces this; never set colours by hand.
3. **Light, dark, or system mode.** Every screen must look right in both
   light and dark mode.
4. **Red only for problems and deleting.** Use the theme's `error`
   colour, never a hand-picked red.
5. **Never colour alone.** Red text also says what is wrong in words.
6. **Colours users pick for their own things.** A habit can have its
   own colour, used only for its name and its ✓ marks, so habits are
   easy to tell apart. Without one it uses the accent colour. Such
   colours come from the same list as the accent colours, are picked
   with `ColorCircle`s, and keep their hue in light and dark mode, made
   only as much lighter or darker as it takes to read on the background
   (`Habit.displayColor`, `readableOn`): a yellow habit is a deeper
   yellow in light mode. Nothing else on the screen takes them.
8. **Pure white text in dark mode**, for the clearest contrast; grey
   text stays grey. **True black** is an option in Settings for OLED
   screens: the background is black, cards the darkest greys.
9. **One colour for the whole app.** Modules have no colours of their
   own: tab icons, tile icons, bars and badges all use the accent, and
   tiles sit on the plain card surface. The app stays calm, and the
   only other colours on screen are the ones users picked for their
   habits.
10. **Flat cards.** Cards have no shadow and sit on a slightly different
   surface (`surfaceContainer`), the same in light and dark mode.


## 10. Density, spacing and sizes

Ippo is a logging tool, so it is **compact**: more fits on a screen,
with less scrolling. Compact is about how things *look*; every tap
target still stays at least 48 × 48 (Android's accessibility
guidance).

- The theme sets dense text fields (`isDense`) padded to 48 high, and
  `VisualDensity.standard`, so every button keeps its 48 × 48 tap area
  (compact density shrank them to 40). Do not change this per screen.
- Put things that belong together **on one row** when they fit:
  − Reps + and Add set; Protein, Carbs and Fat; Woke up and Went to bed.
- Leave out lines that only repeat what the screen already shows (no
  "No sets yet" above empty fields that obviously take sets).

All spacing comes from the scale in `Spacing`
(`lib/core/widgets/section_card.dart`). **Gaps inside a group are
always smaller than gaps between groups**, which is what makes the
grouping visible without extra lines or boxes.

| Name | Size | Where |
| --- | --- | --- |
| `Spacing.tight` | 4 | A label and its value; chips in a wrapped row |
| `Spacing.small` | 8 | Fields side by side; between cards; between Home tiles |
| `Spacing.medium` | 12 | Inside a card's edge; between groups inside a card |
| `Spacing.screen` | 16 | The screen's left and right edges |

Fixed sizes:

| Where | Size |
| --- | --- |
| Card header height | 36, icon 20 |
| Home tile icon | 16 |
| Smallest tap target | 48 × 48 (exception: the day grids, see [Accessibility](#13-accessibility)) |
| Room under the last card when there is a floating button | 96 |


## 11. Feedback: saving, errors, undo

- **Every tap answers at once.** Marking a habit, adding sets and
  saving a sleep day give a light haptic tick
  (`HapticFeedback.selectionClick`) straight away, before saving. It
  follows the phone's own haptics setting.
- **Changes are visible.** A mark that changes animates briefly
  (`AnimatedSwitcher`, 150 ms); sections open and close with
  `AnimatedSize` (200 ms). Keep motion short and never make meaning
  depend on it.
- **Data stays fresh.** The data folder is read again whenever the app
  comes back to the foreground, and every main screen can be pulled
  down to refresh (`RefreshIndicator`).

- **Saving is immediate.** After Save, the form closes and the new entry
  shows on the screen.
- **A failed save** shows "Not saved: …" at the bottom of the screen
  (`saveOrShowError`), and nothing changes.
- **Deleting** closes the form and shows "Deleted …" with an **Undo**
  button (`showUndoMessage`). The message hides itself after five
  seconds and has an ✕ to close it at once.
- **Typed values that do not make sense** show a problem text in red
  under the field, and the Save button is disabled or refuses to save.


## 12. Empty, loading and problem states

| State | Show |
| --- | --- |
| Nothing logged yet | A note in the card: "No naps on this day.", "Nothing logged on this day." |
| Nothing exists yet (no exercises) | A note explaining the first step: "Tap \"New exercise\" to start." |
| Loading | A centred progress circle, only while the app starts |
| No data folder | A short explanation and a button leading to Settings |
| Unreadable data | A red line under the day bar: "2 entries in the data could not be read and are not shown." |


## 13. Accessibility

Ippo follows **WCAG 2.2 level AA** and Android's accessibility
guidance. `test/accessibility_test.dart` checks every main screen, in
light and dark mode with the demo data, using Flutter's guideline
checks; a new screen should be added there.

Sources:
[WCAG 2.2](https://www.w3.org/TR/WCAG22/),
[Android: make apps more accessible](https://developer.android.com/guide/topics/ui/accessibility/apps),
[Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing),
[MDN mobile accessibility checklist](https://developer.mozilla.org/en-US/docs/Web/Accessibility/Guides/Mobile_accessibility_checklist).

**Touch**

- Tap targets are at least 48 × 48 (Android). Flutter's buttons are,
  with the theme's standard density; custom controls (colour circles)
  are made 48 too.
- The one exception is the **day grids**: the habit grid's cells and
  the columns of Home's week. Seven days must fit across a phone, so
  a cell is about 36 wide. That still meets WCAG 2.2 AA (24 × 24,
  criterion 2.5.8), which the test checks there, and the same day can
  always be reached with the day bar's full-size buttons.

**Screen readers**

- Every icon-only button has a `tooltip`, which screen readers read out.
- Things that are read together are one item for screen readers
  (`MergeSemantics` on Home tiles); chips and habit names say what a tap
  does ("Set 1: 20 reps", "Edit habit").
- Colour swatches, grid cells and other custom controls have a
  `Semantics` label ("Orange accent colour", "Read 10 pages, Mon 16 Nov:
  done").

**Contrast**

- Text is at least 4.5:1 against its background (3:1 for large text),
  marks and outlines 3:1 (WCAG 1.4.3 and 1.4.11).
- Contrast comes from the theme; do not put text on hand-picked colours.
  A user's colour (a habit's, the accent) is passed through
  `readableOn` with `textContrast` before it is used for text.
- White text on the landscape (Home's header) sits on a faint dark
  backing or shadow, in light mode too.
- Nothing is told by colour alone: a habit's day is also filled, an
  outline or a dash, and read out by name.

**Text size**

- Text uses the theme's styles, so it follows the phone's text size.
- Every screen must fit with text 2 times as large, without anything
  cut off (the test checks 1.5 and 2): let rows wrap (`Wrap`), let
  headers grow, and shrink only small side values (`FittedBox`), never
  the main text.
- With large text, Home shows one tile per row rather than shrinking
  values.


## 14. Template for a new module screen

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('Module name'),
    // With FollowsToday mixed into the screen's State.
    actions: [DayBar(day: shownDay, onChanged: showDay)],
  ),
  body: ListenableBuilder(
    listenable: appState,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SectionCard(
          children: [
            CardHeader(
              icon: Icons.some_icon,
              title: 'Section',
              action: HeaderAddButton(onPressed: addToSection),
            ),
            const NoteText('Nothing logged on this day.'),
          ],
        ),
      ],
    ),
  ),
);
```

Screens get a module's state with `SomeLog.of(appState)` (for example
`FoodDiary.of(appState)`), never by rebuilding it from the events
themselves: `AppState.derived` works it out once per change of the data
and shares it, which keeps every screen fast as years of data build up.

A new module also needs:

- `homeTile` (its tile on Home), and if it has them, `weekRows` (its
  rows of the week grid), `trendMeasures` (its rows of Lately),
  `charts` (its charts on the Charts screen),
  `datesLogged` (days with anything logged, for Lately's last line),
  `demoEvents` (its demo data) and
  `buildSettingsCard` (a card in Settings), from `IppoModule`;
- an entry in `lib/modules/all_modules.dart`;
- its screens in `test/screens_fit_test.dart`, with long sample data.


## 15. Checklist

Before a screen is done:

- [ ] It follows the structure in section 2.
- [ ] Every element is clearly a field, information, a note, a problem
      or an action (section 3).
- [ ] Actions are where section 4 says.
- [ ] Wording, numbers and icons follow sections 6 to 8.
- [ ] It looks right in light and dark mode, with the system colour and
      with a picked colour.
- [ ] `test/screens_fit_test.dart` passes (narrow screen, light and dark,
      long names).
- [ ] It was looked at on a phone.
