# Ippo

**Ippo** (一歩, "one step") is a free, open-source personal health app
for Android and the Linux desktop. The name comes from the saying
千里の道も一歩から: "a journey of a thousand miles begins with a single
step."

> **Status:** early development. Not ready for daily use yet.

## What it will do

Ippo is built from modules:

- **Habits:** daily check-offs, history, and a habit strength score.
- **Exercise:** log the sets and reps of each exercise, quickly.
- **Food diary:** a simple calorie tracker.
- **Time tracking:** tap what you are doing now; see how each day was
  spent.
- **Sleep:** when you went to bed and woke up, plus naps.

You can add more modules without changing the existing ones.

## Your data stays yours

- **No network.** The Android app does not request the `INTERNET`
  permission, so the system itself blocks it from going online.
  No accounts, ads, telemetry, or analytics.
- **Plain files in a folder you choose.** Your data is stored as
  human-readable JSON Lines files. Open them in any text editor, load
  them into pandas with the small package in [`python/`](python/README.md),
  or export them as CSV for a spreadsheet. The format is described in
  full in [`docs/data-format.md`](docs/data-format.md).
- **Sync with your own tools.** To use Ippo on several devices, sync the
  data folder with a tool such as Syncthing. Each device writes only its
  own file, so syncing does not cause conflicts.
- **Easy to audit.** The code is written to be read. See
  [`docs/permissions.md`](docs/permissions.md) and
  [`docs/dependencies.md`](docs/dependencies.md) for every permission and
  package the app uses, and why.

## Building

See [`docs/development-setup.md`](docs/development-setup.md) to install
the tools, then:

```bash
flutter run -d linux      # run on the Linux desktop
flutter run               # run on a connected Android phone
flutter test              # run the tests
```

## Contributing

Contributions are welcome, especially from beginners. Please read
[`CONTRIBUTING.md`](CONTRIBUTING.md) first.

## License

Ippo is free software, released under the GNU General Public License,
version 3 or later. See [`LICENSE`](LICENSE).
