// SPDX-License-Identifier: GPL-3.0-or-later

/// The nutrition fields shared by "New food" and "Quick food", so both
/// look and work the same.
library;

import 'package:material_ui/material_ui.dart';

import '../nutrients.dart';

/// The nutrients shown straight away: they are on every label and are
/// what most people track.
const List<String> mainNutrientKeys = [
  'proteins_g',
  'carbohydrates_g',
  'fat_g',
];

/// The nutrients behind "More nutrients".
const List<String> moreNutrientKeys = [
  'sugars_g',
  'saturated_fat_g',
  'fiber_g',
  'salt_g',
];

/// Every nutrient field, energy first.
const List<String> allNutrientFieldKeys = [
  energyKey,
  ...mainNutrientKeys,
  ...moreNutrientKeys,
];

/// Short names for the fields, which sit side by side. The same words
/// are used everywhere in the app.
const Map<String, String> nutrientFieldNames = {
  energyKey: 'Energy',
  'proteins_g': 'Protein',
  'carbohydrates_g': 'Carbs',
  'fat_g': 'Fat',
  'sugars_g': 'Sugars',
  'saturated_fat_g': 'Saturated fat',
  'fiber_g': 'Fiber',
  'salt_g': 'Salt',
};

/// Energy across the width; protein, carbs and fat on one row; the rest
/// behind "More nutrients". Only energy is required; the others are
/// simply left empty when not known, so they need no "(optional)".
/// The keyboard's Next key moves from field to field.
class NutritionFields extends StatelessWidget {
  /// Creates the fields.
  const NutritionFields({
    super.key,
    required this.fields,
    required this.isShowingMore,
    required this.onShowMoreChanged,
    this.problems = const {},
  });

  /// One text controller for each key in [allNutrientFieldKeys].
  final Map<String, TextEditingController> fields;

  /// A problem to show under a field, by key.
  final Map<String, String?> problems;

  /// Whether the less common nutrients are shown.
  final bool isShowingMore;

  /// Called to show or hide the less common nutrients.
  final ValueChanged<bool> onShowMoreChanged;

  Widget _field(String key) {
    return TextField(
      controller: fields[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: nutrientFieldNames[key],
        suffixText: key == energyKey ? 'kcal' : 'g',
        errorText: problems[key],
      ),
    );
  }

  /// Fields side by side, with the usual gap.
  Widget _row(List<String> keys) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < keys.length; index++) ...[
          if (index > 0) const SizedBox(width: 12),
          Expanded(child: _field(keys[index])),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(energyKey),
        const SizedBox(height: 12),
        _row(mainNutrientKeys),
        // Opens and closes smoothly, so it is clear what changed.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: isShowingMore
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      _row(moreNutrientKeys.sublist(0, 2)),
                      const SizedBox(height: 12),
                      _row(moreNutrientKeys.sublist(2)),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () => onShowMoreChanged(!isShowingMore),
            icon: Icon(isShowingMore ? Icons.expand_less : Icons.expand_more),
            label: Text(isShowingMore ? 'Fewer nutrients' : 'More nutrients'),
          ),
        ),
      ],
    );
  }
}
