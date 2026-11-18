# Design rules

These rules keep every screen of Ippo consistent, quick to use, and
easy to read. Follow them for every new screen and module. If a rule
gets in the way, change the rule here first, then every screen.

The building blocks live in `lib/core/widgets/section_card.dart`. Use
them instead of styling things by hand. The Sleep screen is the
reference example: when in doubt, make a screen look like it.


## 1. Purpose first

1. **Logging is fast.** The everyday entry takes one or two taps on the
   module's own screen, with sensible values already filled in (last
   night's bedtime, the last set's reps).
2. **Nothing that is not needed.** No decoration, no quotes, no
   statistics or charts unless someone asks for them. Analysis happens
   outside the app, on the plain data files.
3. **Plain words.** Short sentences, everyday words, sentence case
   ("Went to bed", not "SLEEP ONSET").


## 2. Screen layout

1. **Every module screen** has a top bar with its name, then a
   `DayBar` (‹ Today ›) if it shows one day, then its cards.
2. **Each section is a `SectionCard`** that starts with a `CardHeader`:
   an icon and a title on the left, and at most one action on the right.
3. **Cards are listed top to bottom** with the same spacing everywhere;
   nothing sits outside a card except the day bar and short notes.
4. **The Home screen** shows a greeting, the date, one line saying what
   is and is not logged today, and one card per module with a one-line
   summary. Tapping a card opens the module.


## 3. What things look like

Anyone should be able to tell at a glance what can be changed, what is
only information, and what does something.

| Kind | Looks like | Building block |
| --- | --- | --- |
| Something you can change | An outlined field with a label (text fields get this from the theme; times use `TimeField`) | `TextField`, `TimeField` |
| Information | Plain text: a small label above a larger value | `InfoValue`, `InfoRow` |
| A short note or empty state | Muted plain text | `NoteText` |
| A problem | Red text | `ProblemText` |
| An action | A button (see below) | |

Fields that belong together sit **side by side at equal width**, with a
plain gap between them. No symbols between fields (no "×", "→", "–").


## 4. Where actions go

| Action | Where | Example |
| --- | --- | --- |
| Create something for the whole screen | An extended floating button at the bottom right, with an icon and a short label. Stack several at equal width if needed. | **+ New exercise**, **+ Quick food**, **+ New food** |
| An action for one card | A text button at the right of the card's header | **+ Add** (naps), **Edit** (a logged night) |
| Change one row in a list | The row itself, plus a ✎ button at its end | a food entry, a nap |
| Save a form | One full-width filled button at the bottom | **Save**, **Save night** |
| Delete | A red text button under the Save button, followed by an Undo message that hides itself after five seconds | **Delete this nap** |

A screen has at most one filled button in view at a time, so the main
action is always obvious.


## 5. Lists

Each row has a title (the thing) and a subtitle with the details in a
fixed order, separated by " · ": time, amount, then value. For example
"07:30 · 150 g · 280 kcal". Rows are listed in the order they happened.


## 6. Colour

1. **One accent colour.** Every accent-coloured part uses the same main
   shade; highlights (the selected tab, a selected option) use a light
   tint of it. Never mix several unrelated shades.
2. **Follow the phone by default.** On Android 12 and later the accent
   comes from the phone's system colours, so Ippo matches the rest of the
   phone. The user can pick another colour in Settings > Appearance.
3. **Light, dark, or system.** Every screen must look right in both
   light and dark mode.
4. **Never put meaning in colour alone.** Red problem text also says
   what is wrong in words.


## 7. Checking a screen

Before a screen is done:

1. `test/screens_fit_test.dart` passes: it opens every tab on a narrow
   phone screen, in light and dark mode, with long sample names, and
   fails if anything does not fit.
2. Look at it on a phone, in light and dark mode.
3. Check each rule above, especially "what is a button and what is
   information".
