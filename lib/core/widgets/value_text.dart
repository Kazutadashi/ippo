// SPDX-License-Identifier: GPL-3.0-or-later

/// A value such as "7 h 30 min", with the numbers large and the units
/// small.
library;

import 'package:material_ui/material_ui.dart';

/// Matches a run of digits, with the marks that belong inside numbers:
/// "1 240", "12.5", "07:30", "1 / 4" are each read as numbers.
final RegExp _numberPattern = RegExp(r'\d[\d.,:/ ]*\d|\d');

/// Shows [value] with its numbers in [style] and its words (units such
/// as "kcal", "h", "min", "ago") smaller and gray.
///
/// In a value, the numbers carry the information and the units are only
/// context; giving them the same size makes "9 h 15 min ago" read like a
/// sentence. A value without digits ("All done") is shown whole in
/// [style].
class ValueText extends StatelessWidget {
  /// Creates the text.
  const ValueText(
    this.value, {
    super.key,
    required this.style,
    required this.unitStyle,
  });

  /// The value, for example `260 kcal`.
  final String value;

  /// The style of the numbers.
  final TextStyle? style;

  /// The style of the words between and after the numbers.
  final TextStyle? unitStyle;

  @override
  Widget build(BuildContext context) {
    if (!value.contains(RegExp(r'\d'))) {
      return Text(value, style: style, maxLines: 1);
    }
    final parts = <TextSpan>[];
    var position = 0;
    for (final number in _numberPattern.allMatches(value)) {
      if (number.start > position) {
        parts.add(
          TextSpan(
            text: value.substring(position, number.start),
            style: unitStyle,
          ),
        );
      }
      parts.add(TextSpan(text: number.group(0), style: style));
      position = number.end;
    }
    if (position < value.length) {
      parts.add(TextSpan(text: value.substring(position), style: unitStyle));
    }
    // Screen readers get the plain value, read in one go.
    return Text.rich(
      TextSpan(children: parts),
      maxLines: 1,
      semanticsLabel: value,
    );
  }
}
