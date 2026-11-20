# Dependencies

This file lists every package Ippo depends on, what it does, and why we
need it. Fewer dependencies means less code to audit. See the
Dependencies section of `CONTRIBUTING.md` before adding one.

The exact versions in use are pinned in `pubspec.lock`.

## App dependencies

| Package | Maintained by | What it does | Why we need it |
| --- | --- | --- | --- |
| `flutter` | Flutter team | The UI framework the whole app is built on. | It is the app's foundation. |
| `material_ui` | Flutter team | Material Design widgets (buttons, lists, app bars, themes). Newer Flutter versions moved these out of the core framework into this package. | Building these standard widgets ourselves would add a lot of code with no benefit. |
| `flutter_math_fork` | Community (a maintained fork of `flutter_math`) | Draws LaTeX formulas natively, in Dart, without a web view. | The "How these are worked out" screen shows every formula Ippo uses (BMR, daily amounts) typeset as in the papers it cites, so the numbers can be checked. |

`flutter_math_fork` brings in other packages: `flutter_svg` and the
`vector_graphics` packages (drawing), `provider`, `tuple`, `xml`,
`petitparser`, `path_parsing`, `typed_data` and `http` with
`http_parser` (which `flutter_svg` uses to load pictures from the
web). Ippo never loads anything from the web, and its release build has
no `INTERNET` permission (see `docs/permissions.md`), so that code can
never reach the network.

## Development-only dependencies

These help us build and test the app. They are not part of the app you
install.

| Package | Maintained by | What it does | Why we need it |
| --- | --- | --- | --- |
| `flutter_test` | Flutter team | Runs the automated tests. | Every change that touches data needs tests. |
| `flutter_lints` | Flutter team | The standard set of code checks used by `flutter analyze`. | Catches common mistakes and keeps the code consistent. |

## Python package dependencies

The package in `python/` is separate from the app; the app does not use
it.

| Package | Maintained by | What it does | Why we need it |
| --- | --- | --- | --- |
| `pandas` | pandas team | Tables of data, with dates, grouping and CSV files. | It is what most people analyse data with in Python, so the tables are ready to use. |

The scripts in `python/examples/` also use `matplotlib`, the standard
Python charting library, to draw charts. The package itself does not
need it.

## Artwork

The launcher icon is the Home header's landscape at night (a snowy range
shaded away from the moon, hills and spruces, in the header's colours),
drawn for Ippo as vectors in `android/app/src/main/res/drawable/`. The
header itself (`lib/core/widgets/sky_header.dart`) and the dumbbell and
moon icons are drawn in code. None of it uses artwork or fonts from other
projects.
