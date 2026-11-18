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
