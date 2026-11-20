// SPDX-License-Identifier: GPL-3.0-or-later

/// Facts about this build of the app, for the About screen.
///
/// The commit and author are not written in the code: `tool/build.sh`
/// reads them from git when building and passes them in with
/// `--dart-define`. So the repository never names anyone, and every
/// build says exactly which code it was made from. A build made without
/// the script (for example `flutter run`) shows them as unknown.
library;

/// The app's version. Keep it the same as `version` in `pubspec.yaml`
/// (a test checks this).
const String appVersion = '0.1.0';

/// The short id of the git commit this build was made from, such as
/// `e42cd7f`, with `+changes` if the code had uncommitted changes; empty
/// if unknown.
const String buildCommit = String.fromEnvironment('IPPO_COMMIT');

/// When that commit was made, as ISO 8601 with its time zone offset;
/// empty if unknown.
const String buildCommitDate = String.fromEnvironment('IPPO_COMMIT_DATE');

/// Who started the project: the author of the repository's first
/// commit; empty if unknown.
const String buildAuthor = String.fromEnvironment('IPPO_AUTHOR');
