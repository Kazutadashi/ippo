#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Builds Ippo with the facts the About screen shows, read from git:
# the commit it was built from, that commit's date, and the project's
# author. Nothing personal is stored in the code; it comes from git at
# build time.
#
# The author is the git setting "ippo.author" if you set one (it stays in
# your own .git/config and is never committed), for example
#   git config ippo.author "your-name"
# and otherwise whoever made the repository's first commit.
#
# Usage, from the repository's top folder:
#   tool/build.sh apk          # Android release APK (release is the default)
#   tool/build.sh linux        # Linux desktop release
#   tool/build.sh apk --debug  # extra flags go on to "flutter build"
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: tool/build.sh apk|linux [flutter build flags]" >&2
  exit 1
fi
target="$1"
shift

commit="$(git log -1 --format=%h)"
# Mark builds with uncommitted changes, so the stamp never lies.
if [ -n "$(git status --porcelain)" ]; then
  commit="$commit+changes"
fi
commit_date="$(git log -1 --format=%cI)"
author="$(git config --get ippo.author || git log --reverse --format=%an | head -n 1)"

# Say which key signs an Android build, so a test build is never shared
# by mistake. See "Signing a release" in docs/development-setup.md.
if [ "$target" = "apk" ] || [ "$target" = "appbundle" ]; then
  if [ -n "${IPPO_KEY_PROPERTIES:-}" ] && [ -f "$IPPO_KEY_PROPERTIES" ]; then
    echo "Signing with the release key named in \$IPPO_KEY_PROPERTIES."
  elif [ -f android/key.properties ]; then
    echo "Signing with the release key named in android/key.properties."
  else
    echo "No release key found: signing with the debug key. Fine for testing;"
    echo "do not share this build. See docs/development-setup.md."
  fi
fi

flutter build "$target" \
  --dart-define=IPPO_COMMIT="$commit" \
  --dart-define=IPPO_COMMIT_DATE="$commit_date" \
  --dart-define=IPPO_AUTHOR="$author" \
  "$@"
