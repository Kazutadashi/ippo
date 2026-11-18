# Permissions

This file lists every permission Ippo asks for, with a plain-language
reason. If a permission is not listed here, the app does not request it.
Ippo asks for as few permissions as possible.

## Android (release build)

Ippo's release build currently requests **no permissions**.

In particular, the app **never** requests `android.permission.INTERNET`.
Without it, Android blocks all network access for the app, so you do
not have to trust our word that it never goes online. A test
(`test/no_internet_permission_test.dart`) fails if anyone adds this
permission to the release manifest.

### Not permissions, but worth knowing

The main manifest (`android/app/src/main/AndroidManifest.xml`) has a
`<queries>` entry for the `PROCESS_TEXT` action. Flutter adds this by
default. It lets the app see which installed apps can act on selected
text (for example a translator in the text selection menu). It grants
no access to your data and no network access.

## Android (debug and profile builds only)

| Permission | Why |
| --- | --- |
| `INTERNET` | The Flutter developer tools need it to talk to the running app (hot reload, breakpoints). It is only in `android/app/src/debug/` and `android/app/src/profile/`, which are never part of a release build. |

## Linux desktop

Linux desktop apps have no permission system of their own. Ippo only
reads and writes files inside the data folder you choose in settings,
and all of that code lives in one small storage part of the core.
