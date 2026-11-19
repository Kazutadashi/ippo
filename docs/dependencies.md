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

## Artwork from other projects

| What | From | Licence | Where |
| --- | --- | --- | --- |
| The character 歩 on the launcher icon | The brush font Yuji Boku, by the Yuji Project Authors (Kinuta Font Factory); only this one letter's outline, not the font | SIL Open Font License 1.1 (allows use in artwork) | `android/app/src/main/res/drawable/ic_launcher_foreground.xml` and `ic_launcher_monochrome.xml`, and the `ic_launcher.png` files made from it |

The mountains behind it are drawn by hand for Ippo.
