// SPDX-License-Identifier: GPL-3.0-or-later

/// Every saved food, to look over and change.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/app_state.dart';
import '../../../core/widgets/section_card.dart';
import '../food.dart';
import '../food_diary.dart';
import '../nutrients.dart';
import 'food_form_screen.dart';

/// All the foods you saved, by name, with a search box. Tap one to
/// change its name, label values, serving or ingredients, or to delete
/// it. Past entries keep their own copy of what they were logged with.
class FoodsScreen extends StatefulWidget {
  /// Creates the screen.
  const FoodsScreen({super.key, required this.appState});

  /// The app-wide state.
  final AppState appState;

  @override
  State<FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends State<FoodsScreen> {
  String _search = '';

  void _open(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your foods')),
      body: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final search = _search.trim().toLowerCase();
          final foods =
              FoodDiary.of(widget.appState).foods.values
                  .where((food) => !food.isDeleted)
                  .where((food) => food.name.toLowerCase().contains(search))
                  .toList()
                ..sort(
                  (first, second) => first.name.toLowerCase().compareTo(
                    second.name.toLowerCase(),
                  ),
                );
          return ListView(
            padding: belowNavigationBar(
              context,
              const EdgeInsets.fromLTRB(16, 4, 16, 24),
            ),
            children: [
              // A new food: in the right half, where the tabs have their
              // add buttons.
              Row(
                children: [
                  const Spacer(),
                  const SizedBox(width: Spacing.small),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          _open(FoodFormScreen.add(appState: widget.appState)),
                      icon: const Icon(Icons.add),
                      label: const Text('New food'),
                    ),
                  ),
                ],
              ),
              SectionCard(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search your foods',
                    ),
                    onChanged: (text) => setState(() => _search = text),
                  ),
                  const SizedBox(height: 8),
                  const NoteText('Tap a food to change or delete it.'),
                  if (foods.isEmpty)
                    const NoteText('No foods here yet.')
                  else
                    for (var index = 0; index < foods.length; index++) ...[
                      if (index > 0) const Divider(height: 1),
                      _FoodRow(
                        food: foods[index],
                        onTap: () => _open(
                          FoodFormScreen.edit(
                            appState: widget.appState,
                            food: foods[index],
                          ),
                        ),
                      ),
                    ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One food: its name, its serving and what is known about it, and its
/// energy per 100 g at the right.
class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.food, required this.onTap});

  final Food food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final serving = food.serving;
    final nutrientCount = food.nutrientsPer100.values.length;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(food.name, style: textTheme.titleMedium),
      subtitle: Text(
        [
          if (serving != null) serving.describe(food.measuredIn),
          '$nutrientCount nutrients',
          if (food.ingredients != null) 'ingredients',
        ].join('   '),
        style: textTheme.bodySmall?.copyWith(color: muted),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatEnergy(food.nutrientsPer100.energyKcal),
            style: textTheme.titleSmall,
          ),
          Text(
            'per 100 ${food.measuredIn}',
            style: textTheme.labelSmall?.copyWith(color: muted),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
