# Contributing

Thank you for wanting to help! This project is meant to be easy to read,
easy to change, and easy to trust. Every rule below serves that goal.

If you are new to programming, Flutter, or open source: you are welcome
here. If any code in this repository is hard for you to understand, that
is a bug in the code, not in you. Please open an issue and say so.


## The core idea: simple beats clever

We follow the spirit of the Zen of Python (`import this`), in both the
Dart app code and the Python analysis code:

- Readability counts.
- Explicit is better than implicit.
- Simple is better than complex.
- Flat is better than nested.
- Errors should never pass silently.
- There should be one obvious way to do it.
- If the implementation is hard to explain, it's a bad idea.

Simple code is also safer code. When code is plain and obvious, bugs and
security problems have nowhere to hide.


## Writing code

### Be obvious
- Write code a beginner could follow. Choose the boring, plain solution.
- No clever tricks: no dense one-liners, no metaprogramming, no
  reflection, no "magic" that happens somewhere else.
- Avoid code generation (for example `build_runner`, `freezed`,
  `json_serializable`). Write the code by hand so readers can see it.
- Prefer a few extra lines that are clear over a short line that is not.

### Name things well
- Use full, descriptive names: `completedHabits`, not `ch` or `cHabs`.
- Functions are named for what they do: `loadEventsFromFolder()`.
- Booleans read like questions: `isCompleted`, `hasSynced`.

### Keep things small
- A function does one job. If you need "and" to describe it, split it.
- A file holds one main idea (one class, one screen, one module).
- Keep nesting shallow. Return early instead of stacking `if` blocks.

### Comment and document
- Every public class, function, and field gets a doc comment
  (`///` in Dart, docstrings in Python).
- A doc comment says what the thing does, what it takes, what it
  returns, and what can go wrong.
- Inline comments explain **why**, not what. The code already says what.
- If you had to think hard to write something, leave a comment for the
  next person.

### Handle errors honestly
- Never swallow an error silently. Show it, log it, or pass it up.
- Never delete or overwrite user data to "fix" a problem.
- If a line in a data file cannot be read, skip it, warn the user, and
  leave the file untouched.


## Structure

### Modules
Features (habits, calisthenics, meals, ...) are **modules**.

- Each module lives in its own folder and can be understood on its own.
- The core app knows nothing about any specific module. It only offers
  shared services: reading and writing events, settings, navigation.
- Modules never import from each other. If two modules need the same
  thing, it belongs in the core.
- Adding a new module should not require changing existing modules.

### Data
- The data is the product: follow `docs/data-principles.md` for
  anything that records, changes or exports data.
- All data is stored as plain, human-readable files the user controls.
- The app works with **any data folder the user chooses**. Never
  hard-code paths, device names, or personal data.
- Data files are append-only. See `docs/data-format.md` for the format.
- Every event records a format version, so old data keeps working.


## Screens

Every screen follows the rules in [`docs/design.md`](docs/design.md):
what fields, information and buttons look like, where actions go, how
lists and colours work, and how to check a screen. Build screens from
the pieces in `lib/core/widgets/section_card.dart`, and keep
`test/screens_fit_test.dart` passing when you add a module.


## Dependencies

- Add a package only when writing the code yourself would be clearly
  worse. Every dependency is code we must trust and keep updated.
- Prefer packages maintained by the Dart/Flutter team.
- Use Flutter's built-in state tools (`setState`, `ChangeNotifier`)
  rather than large state-management frameworks.
- When you add a dependency, explain why in your pull request.


## Privacy and security

- The app never uses the network. No telemetry, analytics, ads, or
  accounts.
- User data never leaves the device except through the user's own sync.
- Treat data files as untrusted input: validate what you read and
  handle bad data without crashing.
- Never commit personal information: no real names, emails, file paths,
  home directories, environment variables, device names, or personal
  habits and data, in code, comments, tests, config files, examples, or
  screenshots. Paths are chosen by the user in the app or come from
  platform APIs, never typed into the code. Use generic placeholders such as `my-phone`
  and `/path/to/data`.
- Each user's own setup (their habits, exercises, foods, device name,
  data folder) lives in their data folder and app settings, never in
  the code.


## Auditability

People should be able to trust this app because they can check it
themselves, not because we ask them to. Anyone, including non-experts,
should be able to read the code and confirm what the app does with their
data. Clear code is what makes that possible.

- **One door to the disk.** All reading and writing of user files goes
  through a single, small storage part of the core. No other code
  touches the file system. An auditor only needs to read that one place
  to know exactly what the app reads and writes.
- **No network, provably.** The Android release build does not request
  the `INTERNET` permission, so the operating system itself blocks any
  network access. Never add it.
- **Every permission is justified.** Each permission the app requests is
  listed in `docs/permissions.md` with a plain-language reason. Ask for
  the fewest permissions possible.
- **Every dependency is justified.** Each package is listed in
  `docs/dependencies.md` with what it does and why we need it. Fewer
  dependencies means less code to audit.
- **Nothing hidden.** No obfuscation, no minified or generated code
  checked in, no binary blobs, no code downloaded at runtime.
- **Readable data.** Data files are plain text that a person can open and
  read, so users can see exactly what the app has stored about them.
- **Clear history.** Small, focused commits with descriptive messages,
  so each change can be reviewed on its own.


## License

Ippo is free software under the GNU General Public License, version 3
or later (`GPL-3.0-or-later`). See `LICENSE`. By contributing, you agree
that your contribution is released under the same license.

Start every source file with this one line, so each file states its
license on its own:

- Dart: `// SPDX-License-Identifier: GPL-3.0-or-later`
- Python: `# SPDX-License-Identifier: GPL-3.0-or-later`


## Before you open a pull request

- `dart format .` — code is formatted.
- `flutter analyze` — no warnings.
- `flutter test` — all tests pass.
- New logic (especially anything touching data) has tests.
- New public code has doc comments.
- Python code passes `ruff check` and `ruff format`, and
  `python -m unittest` passes in the `python` folder.
- A change to the data format updates `docs/data-format.md`, the Python
  package, and `example-data/` with the tests that read it, together.
