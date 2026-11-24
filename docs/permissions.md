# Permissions

This file lists every permission Ippo asks for, with a plain-language
reason. If a permission is not listed here, the app does not request it.
Ippo asks for as few permissions as possible.

## Android (release build)

Ippo's release build requests **no permissions** that reach your data,
your device or the network. The one permission an installed APK lists
is Ippo's own, explained below.

In particular, the app **never** requests `android.permission.INTERNET`.
Without it, Android blocks all network access for the app, so you do
not have to trust our word that it never goes online. A test
(`test/no_internet_permission_test.dart`) fails if anyone adds this
permission to the release manifest.

### The one permission listed: Ippo's own

| Permission | Why |
| --- | --- |
| `<app id>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Not a permission to anything on your phone. AndroidX Core (`androidx.core`, used by Flutter) defines it for every app, named after the app's id, so that a system message the app listens for can come only from the app itself. Its protection level is `signature`: only apps signed with Ippo's own key could hold it. It gives no access to your data, your device or the network. |

To list an APK's permissions yourself, with the Android SDK's build
tools: `aapt2 dump badging <file>.apk | grep permission`.

### No backups or transfers of the app's own files

Android can copy an app's private files to your cloud backup (your
Google account) or to a new phone. Ippo turns this off
(`android:allowBackup="false"`, and for Android 12 and later
`android:dataExtractionRules`, which excludes everything from both,
in `res/xml/data_extraction_rules.xml`). Those private files are only
the settings (this device's id and name, the chosen folder, display
choices), but they stay on this phone. Your data is in the folder you
chose, which you back up and sync with your own tools. After a
reinstall, Ippo starts fresh: choose the folder again and it finds all
your data there. The same test as above checks this.

Ippo also refuses plain, unencrypted network traffic
(`android:usesCleartextTraffic="false"`). It has no network access at
all, so this only makes the intent explicit.

### Not permissions, but worth knowing

**Folder access.** You choose Ippo's data folder in Android's own
folder picker. Android then lets Ippo read and write files in that one
folder only, and nowhere else on your device. This needs no permission
from the list above. If you pick a different folder later, Ippo gives
back its access to the old one. You can also remove the access in
Android's settings for the app. The code for this is in
`android/app/src/main/kotlin/org/ippo/ippo/StorageBridge.kt`.

**System colors.** On Android 12 and later, Ippo reads the phone's
accent color so it can match the rest of the phone. This only reads a
color value; it needs no permission. The code is in
`android/app/src/main/kotlin/org/ippo/ippo/SystemColors.kt`.

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
and all of that code lives in one small storage part of the core
(`lib/core/storage/`).

## The settings file (both platforms)

Besides the data folder, Ippo keeps one small file, `settings.json`,
with this device's id, its name, and (on Linux) the data folder's
path. It lives in the app's own private folder on Android, and in
`$XDG_CONFIG_HOME/ippo/` (usually `~/.config/ippo/`) on Linux. The code
is in `lib/core/storage/settings_file.dart`.
