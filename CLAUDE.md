# Project notes for Claude

## Coding principles (binding)

Follow `CONTRIBUTING.md` for all code in this repo, every session, without
being reminded. In short: beginner-readable, simple over clever, Zen of
Python in spirit, thorough doc comments, comments that explain why, small
files and functions, minimal dependencies, no code generation, no network
access. When unsure between two approaches, pick the more obvious one.

Auditability is a first-class goal: users should be able to trust the
app by reading its code. All file access goes through one small storage
part of the core; no `INTERNET` permission in release builds; every
permission and dependency is documented with a reason
(`docs/permissions.md`, `docs/dependencies.md`). See the Auditability
section of `CONTRIBUTING.md`.

## What this project is

**Ippo** (一歩, "one step", from 千里の道も一歩から: "a journey of a
thousand miles begins with a single step"). A personal health app meant
to become a generic, open-source app that
other people can use and extend. It is a Loop-Habit-Tracker-style app
plus more, built from modules:

1. Habits: daily check-offs, history, Loop-style habit strength score.
2. Calisthenics progression: exercise ladders (Hybrid Calisthenics
   style), log sets/reps, prompt to move up a step at a rep target.
3. Meal diary / calorie tracker.

More modules should be addable without touching existing ones.

Toolchain setup for contributors: `docs/development-setup.md`.

License: GPL-3.0-or-later (`LICENSE`). Every source file starts with an
`SPDX-License-Identifier: GPL-3.0-or-later` comment. Intended for F-Droid.

## Architecture decisions

- **Flutter**, one codebase for Android and Linux desktop.
- **No server, no network.** The app reads and writes plain files in a
  data folder the user picks in settings. It must work with any folder;
  never hard-code paths. Syncing between devices is the user's job
  (for example Synology Drive, Syncthing).
- **Append-only event log, one file per device**:
  `<data folder>/events/<device name>.jsonl`. A device only ever writes
  its own file and reads all of them. This avoids sync conflicts.
- Each line is one JSON event with: a format version, a unique id, an
  ISO 8601 timestamp with time zone offset, the device name, the module,
  the event type, and module-specific data. Edits and deletions are new
  events referencing the original id. Full spec to be written in
  `docs/data-format.md`.
- App state is rebuilt by reading and merging all event files by
  timestamp. Conflicting changes: the most recent wins.
- Data must stay easy to analyze in Python (pandas, Jupyter, ML).
  A small Python helper package for loading events will live in this repo.
- Show when data from each other device was last seen, so users can tell
  if sync has caught up.

## No personal information in the repo

Nothing committed here may reveal anything about the owner or any other
real person: no names, emails, usernames, file paths, home directories,
environment variables, device names, habits, foods, workouts, schedules,
or details of their hardware, OS, or sync setup. Paths are always chosen
by the user at runtime or built from platform APIs, never written out.
(Git commit author info is fine and not covered by this rule.)
Examples, defaults, tests, and sample data use generic placeholders (`my-phone`, `/path/to/data`, "Read 10 pages"). The owner's
own configuration lives only in their data folder, never in the code.
