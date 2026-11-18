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
2. **Only what is needed.** No decoration, quotes, or statistics unless
   someone asks for them. Analysis happens outside the app, on the plain
   data files.
3. **Obvious at a glance.** Anyone can tell what can be changed, what is
   only information, and what does something (see section 3).
4. **The same everywhere.** The same kind of thing looks and sits the
   same on every screen.
5. **Nothing is lost.** Deleting offers Undo. Errors are shown, never
   hidden.


## 2. Screen structure

### The app frame

- A bar along the bottom with one tab per screen: **Home**, then each
  module in `lib/modules/all_modules.dart`, then **Settings**.
- The app opens on Home. A new user without a data folder starts on
  Settings.
- Each tab keeps its state (the day shown, typed numbers) while another
  tab is open.

### A module screen, top to bottom

1. **Top bar** with the module's name ("Sleep") on the left and, if the
   screen shows one day, the day picker (`DayBar`: ‹ Today ›) on the
   right, in `AppBar.actions`. It does not take a row of its own.
2. **Cards** (`SectionCard`), one per section, each starting with a
   `CardHeader`.
4. **Floating buttons** at the bottom right, for creating things for the
   whole screen (section 4).

Nothing sits outside a card except short notes or problems at the top.

### Home

Home is **purely information**, like a weather app: a quick glance at
what matters about the day so far. Nothing on it can be tapped; the bar
at the bottom leads to the modules.

Top to bottom: a greeting ("Good afternoon"), the date ("Wednesday,
18 November"), then a grid of `InfoTile`s, two per row, each row as
tall as its tallest tile.

- Each module gives its tiles through `todayFacts`, usually two, so
  they fill one row.
- A tile has a small icon and label, **one large value**, and one short
  grey detail line: *Last meal · 3 h ago · at 12:15 · Soup*.
- Tiles are what a person needs to know right now. Values worked out
  live ("Awake for", "Last meal", "Last set") are the most useful.
- Tiles keep their place before anything is logged, showing "–" and
  "Not logged yet", so the layout never jumps.

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
(`TextInputAction.next`) to move on to the next field.


## 3. Fields, information and buttons

Every element is exactly one of these kinds, and each kind always looks
the same:

| Kind | Looks like | Use |
| --- | --- | --- |
| **Editable** | An outlined box with a label on its border | `TextField` (the theme adds the outline), `TimeField` for times, `DateTimeField` when the date matters too |
| **Information** | Plain text: a small grey label above a larger value | `InfoValue`, or `InfoRow` for several side by side; `InfoText` for long text such as paths; `InfoTile` on Home |
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
- A field's label says what goes in it ("Went to bed", "Reps"). Add a
  unit as a suffix inside the field ("kg", "g").
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
| Create something for the whole screen | Bottom right, stacked at equal width if more than one | Extended floating button: icon and a short label | **+ New exercise**, **Quick food**, **+ New food** |
| An action for one card | Right side of the card's header | Text button with icon: `HeaderAddButton`, `HeaderEditButton` | **+ Add** (naps), **Edit** (a logged night), **Refresh** |
| Change one row of a list | The whole row, plus a ✎ button at its end | `ListTile` with trailing `IconButton` | a food entry, a nap |
| Save a form screen | Right of the top bar | `AppBarSaveButton` | **Save** (New food, Nap) |
| Save on a module's own screen (not a form) | Bottom of its card, full width | Filled button | **Save** (Sleep's day card) |
| Delete | Under the Save button | Red text button: `DeleteButton` | **Delete this nap** |

- At most **one filled button** is in view on a card or form, so the
  main action is obvious.
- A card header has **at most one** action.
- Leave room at the bottom of a scrolling screen so floating buttons
  never cover the last row (96 pixels for one button, 160 for two).


## 5. Lists

- Each row has a **title** (the thing: "Cheezits", "14:00 – 14:45") and
  a **subtitle** with details.
- Details are in this order, joined by " · ": **time, amount, value**.
  For example "07:30 · 150 g · 280 kcal". Leave out what is not known.
- Rows are in the order things happened.
- Small things a person adds several of in a row (sets) can be chips
  (`ActionChip`); tapping one opens it for changing.


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
| Home tile values | `headlineSmall` (set by `InfoTile`) |
| Home tile labels | `labelLarge`, grey (set by `InfoTile`) |
| Home date | `titleMedium`, grey (`onSurfaceVariant`) |
| Card titles | `titleMedium` (set by `CardHeader`) |
| Information values | `titleMedium` (set by `InfoValue`) |
| Information labels | `labelMedium`, grey (set by `InfoValue`) |
| Notes | `bodyMedium`, grey (set by `NoteText`) |
| Small print (device id) | `bodySmall`, grey |


## 7. Numbers, times and units

| Kind | Format | Examples |
| --- | --- | --- |
| Times of day | 24-hour `HH:MM` | `07:00`, `23:30` |
| Durations | Hours and minutes, no zeros | `7 h 30 min`, `8 h`, `45 min` |
| Time since | Duration and "ago" | `3 h 15 min ago`, `Just now` |
| Dates in lists | `YYYY-MM-DD` | `2026-11-18` |
| Days in the day bar | `Today`, `Yesterday`, `Tomorrow`, else weekday and date | `Mon 2026-11-16` |
| A date and time in a field | Short date above the time | `Thu 19 Nov` / `01:00` |
| Amounts | No needless decimals, at most one | `150`, `12.5` |
| Energy | Number, space, `kcal` | `200 kcal` |
| Weights and nutrients | Number, space, unit | `5 g`, `10 kg` |
| Unknown values | An en dash | `–` |

Use `formatAmount`, `formatDuration`, `formatTimeAgo`,
`formatTimeOfDay` and `describeDay` rather than formatting by hand.


## 8. Icons

- **Material icons that show a thing**: a fork and knife for food, a
  moon for sleep, a dumbbell for exercise.
- **No symbols, letters or emoji-like icons** (no Σ, no smileys).
- **One icon per meaning, everywhere.** Current icons:

| Meaning | Icon |
| --- | --- |
| Home | `home` (outlined when not selected) |
| Food, food eaten | `restaurant` |
| Food totals (energy) | `local_fire_department` |
| Your foods (a list) | `list_alt` |
| Quick food | `bolt` |
| Exercise | `fitness_center` |
| Sleep, a night | `bedtime` |
| A nap | `airline_seat_flat` |
| Settings | `settings` (outlined when not selected) |
| Add, new | `add` |
| Change one thing | `edit_outlined` |
| A time field | `schedule` |
| Data folder | `folder`, `folder_open` to choose one |
| Appearance | `palette` |
| This device | `smartphone` |
| Other devices | `devices`, `devices_other` |
| Read again | `refresh` |
| Time since (last meal, last set) | `schedule` |
| Awake for | `wb_sunny_outlined` |

Card headers show their icon in the accent colour.


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


## 10. Density, spacing and sizes

Ippo is a logging tool, so it is **compact**: more fits on a screen,
with less scrolling. Compact is about how things *look*; every tap
target still stays at least 48 × 48 (Android's accessibility
guidance).

- The theme sets `VisualDensity.compact` and dense text fields
  (`isDense`), so fields, buttons and list rows are shorter
  everywhere. Do not undo this per screen.
- Put things that belong together **on one row** when they fit:
  Reps · Sets · Add, Protein · Carbs · Fat, Woke up · Went to bed.
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
| Smallest tap target | 48 × 48 |
| Room under the last card when there are floating buttons | 96 (one), 160 (two) |


## 11. Feedback: saving, errors, undo

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

- Every icon-only button has a `tooltip`, which screen readers read out.
- Colour swatches and other custom controls have a `Semantics` label
  ("Orange accent colour").
- Tap targets are at least 48 × 48 pixels (Flutter's buttons already
  are).
- Text uses the theme's styles, so it follows the phone's text size.
- Contrast comes from the theme; do not put text on hand-picked colours.


## 14. Template for a new module screen

```dart
Scaffold(
  appBar: AppBar(title: const Text('Module name')),
  floatingActionButton: FloatingActionButton.extended(
    onPressed: createSomething,
    icon: const Icon(Icons.add),
    label: const Text('New thing'),
  ),
  body: ListenableBuilder(
    listenable: appState,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        DayBar(day: day, onChanged: changeDay),
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

A new module also needs:

- `todayFacts` (its Home tiles, usually two), from `IppoModule`;
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
