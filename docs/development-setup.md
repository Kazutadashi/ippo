# Development setup

This guide installs everything needed to build Ippo for Android and the
Linux desktop. Android Studio is **not** required; the command-line tools
are enough.

The commands below use Arch Linux package names. On other distributions,
install the same tools with your package manager. For macOS and Windows,
see Flutter's official install guide: https://docs.flutter.dev/get-started

You can put the Flutter SDK and Android SDK anywhere you like. This guide
uses `~/development/flutter` and `~/Android/Sdk`.


## 1. System packages

```bash
sudo pacman -S --needed base-devel git unzip zip xz clang cmake ninja gtk3 pkgconf jdk17-openjdk android-tools
```

- `clang`, `cmake`, `ninja`, `gtk3`, `pkgconf` build the Linux desktop app.
- `jdk17-openjdk` is the Java version Android builds expect.
- `android-tools` provides `adb`, which installs the app on a phone.


## 2. Flutter SDK

```bash
mkdir -p ~/development
git clone https://github.com/flutter/flutter.git -b stable ~/development/flutter
```


## 3. Android SDK command-line tools

1. Download **"Command line tools only"** for Linux from
   https://developer.android.com/studio (bottom of the page).
2. Unpack it into the folder layout Android expects:

```bash
mkdir -p ~/Android/Sdk/cmdline-tools
cd ~/Android/Sdk/cmdline-tools
unzip ~/Downloads/commandlinetools-linux-*_latest.zip
mv cmdline-tools latest
```


## 4. Environment variables

Add these two lines to the end of your shell startup file
(`~/.bashrc` for bash):

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$HOME/development/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
```

- `ANDROID_HOME` tells Flutter and the Android build tools where the
  Android SDK is.
- The `PATH` line lets you run `flutter`, `dart`, `sdkmanager`, and `adb`
  from any folder. It only adds folders; your existing `PATH` is kept.

Then load them into your current terminal:

```bash
source ~/.bashrc
```


## 5. Configure Flutter

```bash
flutter config --jdk-dir /usr/lib/jvm/java-17-openjdk
flutter config --no-analytics
dart --disable-analytics
```


## 6. Android SDK packages and licenses

```bash
sdkmanager "platform-tools" "platforms;android-36" "build-tools;36.0.0"
flutter doctor --android-licenses
```

Answer `y` to each license. If `flutter doctor` later asks for a
different platform or build-tools version, install that one the same way.


## 7. Check everything

```bash
flutter doctor -v
```

You need green checks for **Flutter**, **Android toolchain**, and
**Linux toolchain**. Warnings about Chrome and Android Studio can be
ignored.

Wayland works out of the box (Flutter's Linux apps use GTK3). If the app
looks wrong on your compositor, run it through XWayland with
`GDK_BACKEND=x11`.


## 8. Connect an Android phone

1. Settings → About phone → tap **Build number** 7 times to unlock
   Developer options.
2. Settings → System → Developer options → turn on **USB debugging**.
3. Plug the phone in and run `adb devices`. Accept the prompt on the
   phone. It should be listed as `device`.
   - If it shows `no permissions` on Arch, run
     `sudo pacman -S android-udev`, then unplug and replug the phone.

Ippo does not need Google Play services, so it also runs on
de-Googled Android systems.


## 9. Python tools (optional, for data analysis)

Any Python 3.12+ environment works. With conda:

```bash
conda create -n ippo python=3.12 pandas pyarrow matplotlib seaborn jupyterlab scikit-learn ruff
```


## Known issue: NVIDIA graphics on the Linux desktop

On computers that draw the screen with an NVIDIA graphics card, the
Linux desktop app may appear shifted: only the bottom-left quarter of
the window shows anything, and it shows the top-right quarter of the
app. This is a Flutter bug,
[flutter/flutter#195885](https://github.com/flutter/flutter/issues/195885).

Until it is fixed, run the app with Mesa (the open-source OpenGL
library) instead of the NVIDIA driver:

```bash
__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json \
MESA_GLES_VERSION_OVERRIDE=3.0 \
flutter run -d linux
```

- The first line makes the app use Mesa. On a computer where the screen
  is connected only to the NVIDIA card, Mesa draws in software on the
  processor. That is slower, but fast enough for Ippo.
- The second line turns on the OpenGL feature whose absence causes the
  bug.
- Both settings apply only to this one command.

In VS Code, you can put the same two variables in the `env` section of
a launch configuration in `.vscode/launch.json`.
