#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Builds the Android files for a release, from the code as committed:
#
#   build/release/ippo-<version>-arm64-v8a.apk     almost every phone today
#   build/release/ippo-<version>-armeabi-v7a.apk   older 32-bit phones
#   build/release/ippo-<version>-x86_64.apk        emulators and a few tablets
#   build/release/ippo-<version>.apk               all of them in one (larger)
#   build/release/SHA256SUMS                       checksums, to check a download
#
# The version is the one in pubspec.yaml. See "Making a release" in
# docs/development-setup.md for the whole procedure.
#
# Usage, from the repository's top folder:
#   tool/release.sh
set -euo pipefail

# A release is built from committed code only, so the version and the
# commit shown in the app's About screen say exactly what it is.
if [ -n "$(git status --porcelain)" ]; then
  echo "There are uncommitted changes. Commit them first." >&2
  exit 1
fi

version="$(grep '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')"
echo "Building Ippo $version."

out="build/release"
rm -rf "$out"
mkdir -p "$out"

# One file per kind of processor: about a third of the size of one file
# for all of them.
tool/build.sh apk --split-per-abi
for abi in arm64-v8a armeabi-v7a x86_64; do
  cp "build/app/outputs/flutter-apk/app-$abi-release.apk" \
    "$out/ippo-$version-$abi.apk"
done

# And one file that works on every phone, for anyone unsure which to
# take.
tool/build.sh apk
cp build/app/outputs/flutter-apk/app-release.apk "$out/ippo-$version.apk"

(cd "$out" && sha256sum ./*.apk > SHA256SUMS)
echo
echo "Done. In $out:"
ls -lh "$out"
