// SPDX-License-Identifier: GPL-3.0-or-later

/// The About screen: the name, who made it, and which build this is.
library;

import 'package:material_ui/material_ui.dart';

import 'build_info.dart';
import 'events/event.dart';
import 'widgets/section_card.dart';

/// What is shown for a build fact that was not passed in (see
/// `build_info.dart`).
const String _unknownBuild = 'Unknown (not built with tool/build.sh)';

/// Shows why the app is called Ippo, who made it, the version and
/// commit it was built from, the data format, and the licence.
class AboutScreen extends StatelessWidget {
  /// Creates the screen.
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About Ippo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const SizedBox(height: 8),
          Text(
            '一歩',
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium?.copyWith(
              color: colors.primary,
            ),
          ),
          Text(
            'Ippo · "one step"',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SectionCard(
            children: [
              const CardHeader(icon: Icons.landscape, title: 'The name'),
              const SizedBox(height: 4),
              Text('千里の道も一歩から', style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                'Senri no michi mo ippo kara: "a journey of a thousand '
                'miles begins with a single step."',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              const NoteText(
                'Each check-off, meal, set or night you log is one small '
                'step. Over months they add up to a record you can look '
                'back on and learn from.',
              ),
            ],
          ),
          SectionCard(
            children: [
              const CardHeader(icon: Icons.info_outline, title: 'This build'),
              const SizedBox(height: 4),
              const _Fact('Version', appVersion),
              _Fact(
                'Commit',
                buildCommit.isEmpty ? _unknownBuild : buildCommit,
              ),
              _Fact('Commit date', _describeCommitDate(buildCommitDate)),
              const _Fact('Data format', 'Version $currentFormatVersion'),
              _Fact(
                'Author',
                buildAuthor.isEmpty ? _unknownBuild : buildAuthor,
              ),
            ],
          ),
          SectionCard(
            children: [
              const CardHeader(icon: Icons.lock_outline, title: 'Privacy'),
              const SizedBox(height: 4),
              const NoteText(
                'Ippo has no internet permission: it cannot send anything '
                'anywhere. Your data is plain text files in the folder you '
                'chose, and only that folder.',
              ),
            ],
          ),
          SectionCard(
            children: [
              const CardHeader(icon: Icons.gavel, title: 'Licence'),
              const SizedBox(height: 4),
              const NoteText(
                'Ippo is free software under the GNU General Public '
                'License, version 3 or later (GPL-3.0-or-later): you may '
                'use, study, change and share it.',
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'Ippo',
                    applicationVersion: appVersion,
                  ),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Licences of the parts Ippo uses'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The commit date for people, such as "2026-11-19 at 14:05", in the
/// time zone it was committed in; or unknown.
String _describeCommitDate(String isoDate) {
  if (isoDate.isEmpty) {
    return _unknownBuild;
  }
  // The written date and time, before the offset: "2026-11-19T14:05:31".
  final match = RegExp(r'^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})')
      .firstMatch(isoDate);
  if (match == null) {
    return isoDate;
  }
  return '${match[1]} at ${match[2]}';
}

/// One fact about the build: its name on the left, the value on the
/// right, wrapping if long.
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
