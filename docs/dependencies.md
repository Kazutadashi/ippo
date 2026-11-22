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
| `pyarrow` (optional) | Apache Arrow project | Writes Apache Parquet files. | Parquet is the standard file format for tables in data science (pandas, R, Polars, DuckDB, Spark), and keeps each column's type. Only installed on request (`pip install ".[parquet]"`); without it the export writes CSV only. |

The scripts in `python/examples/` also use `matplotlib`, the standard
Python charting library, to draw charts. The package itself does not
need it.

## Artwork

The launcher icon (steps climbing toward the rising moon, in three
ridges, in the Home header's night colours) was drawn for Ippo. Its source is
`docs/artwork/launcher-icon.svg`; the same shapes are the vector layers
in `android/app/src/main/res/drawable/ic_launcher_*.xml`. The PNGs for
older Android (`mipmap-*/ic_launcher.png`) are the middle 72 × 72 of
that drawing, rendered with `rsvg-convert` and cropped with ImageMagick
(neither is needed to build the app). The header itself (`lib/core/widgets/sky_header.dart`) and the dumbbell and
moon icons are drawn in code. None of it uses artwork or fonts from other
projects.

The images at the top of the README (`docs/images/`) are made from
Ippo itself: `icon.png` is the launcher icon's SVG rendered with
`rsvg-convert` and rounded with ImageMagick; the three GIFs were
recorded from the app running in Flutter's test environment with its
built-in demo data (taps drawn as circles), and encoded with ffmpeg.
The ✓ and ✗ in them come from Noto Sans Symbols 2 (SIL Open Font
License), added to the recording's copy of Roboto because the test
environment has no system font to supply them; the app itself uses
neither file.
