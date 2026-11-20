// SPDX-License-Identifier: GPL-3.0-or-later

/// Made-up foods, meals and body details for the demo (see
/// `demo_plan.dart`). The body details live here because Food shows
/// them: the calorie limit and the body card in Settings.
library;

import '../../core/dates.dart';
import '../../core/module.dart';
import '../../core/number_input.dart';
import '../body/body_log.dart';
import 'food_diary.dart';
import 'nutrients.dart';

/// One made-up food: its name, g or ml, values per 100, and optionally a
/// serving (pieces, their name, their weight) and ingredients.
typedef _DemoFood = ({
  String name,
  String measuredIn,
  Map<String, double> per100,
  (double, String, double)? serving,
  String? ingredients,
});

const List<_DemoFood> _foods = [
  (
    name: 'Rolled oats',
    measuredIn: 'g',
    per100: {
      'energy_kcal': 379,
      'proteins_g': 13.2,
      'carbohydrates_g': 60,
      'sugars_g': 1,
      'fiber_g': 10.1,
      'fat_g': 6.5,
      'saturated_fat_g': 1.1,
      'iron_mg': 4.3,
      'magnesium_mg': 138,
    },
    serving: (0.5, 'cup', 40),
    ingredients: 'Whole grain rolled oats.',
  ),
  (
    name: 'Milk',
    measuredIn: 'ml',
    per100: {
      'energy_kcal': 64,
      'proteins_g': 3.4,
      'carbohydrates_g': 4.8,
      'sugars_g': 4.8,
      'fat_g': 3.6,
      'saturated_fat_g': 2.3,
      'calcium_mg': 120,
      'vitamin_d_ug': 1.1,
    },
    serving: (1, 'glass', 250),
    ingredients: 'Milk, vitamin D3.',
  ),
  (
    name: 'Greek yogurt',
    measuredIn: 'g',
    per100: {
      'energy_kcal': 97,
      'proteins_g': 9,
      'carbohydrates_g': 3.9,
      'sugars_g': 3.6,
      'fat_g': 5,
      'calcium_mg': 100,
    },
    serving: (1, 'pot', 150),
    ingredients: 'Milk, cream, live cultures.',
  ),
  (
    name: 'Banana',
    measuredIn: 'g',
    per100: {
      'energy_kcal': 89,
      'proteins_g': 1.1,
      'carbohydrates_g': 23,
      'sugars_g': 12,
      'fiber_g': 2.6,
      'fat_g': 0.3,
      'potassium_mg': 358,
    },
    serving: (1, 'banana', 120),
    ingredients: null,
  ),
  (
    name: 'Rice, cooked',
    measuredIn: 'g',
    per100: {
      'energy_kcal': 130,
      'proteins_g': 2.7,
      'carbohydrates_g': 28,
      'fiber_g': 0.4,
      'fat_g': 0.3,
    },
    serving: null,
    ingredients: null,
  ),
  (
    name: 'Chicken breast',
    measuredIn: 'g',
    per100: {
      'energy_kcal': 165,
      'proteins_g': 31,
      'carbohydrates_g': 0,
      'fat_g': 3.6,
      'saturated_fat_g': 1,
      'sodium_mg': 74,
      'salt_g': 0.2,
    },
    serving: null,
    ingredients: null,
  ),
  (
    name: 'Lentil soup',
    measuredIn: 'g',
    per100: {
      'energy_kcal': 72,
      'proteins_g': 4.5,
      'carbohydrates_g': 10,
      'fiber_g': 3.2,
      'fat_g': 1.5,
      'salt_g': 0.6,
    },
    serving: (1, 'bowl', 300),
    ingredients: 'Water, lentils, carrot, onion, tomato, olive oil, salt.',
  ),
  (
    name: 'Wholemeal bread',
    measuredIn: 'g',
    per100: {
      'energy_kcal': 247,
      'proteins_g': 10,
      'carbohydrates_g': 41,
      'fiber_g': 7,
      'fat_g': 3.4,
      'salt_g': 1,
    },
    serving: (1, 'slice', 36),
    ingredients: 'Wholemeal wheat flour, water, yeast, salt.',
  ),
  (
    name: 'Apple',
    measuredIn: 'g',
    per100: {
      'energy_kcal': 52,
      'proteins_g': 0.3,
      'carbohydrates_g': 14,
      'sugars_g': 10.4,
      'fiber_g': 2.4,
      'fat_g': 0.2,
      'vitamin_c_mg': 4.6,
    },
    serving: (1, 'apple', 180),
    ingredients: null,
  ),
  (
    name: 'Potato chips',
    measuredIn: 'g',
    per100: {
      'energy_kcal': 536,
      'proteins_g': 7,
      'carbohydrates_g': 53,
      'fat_g': 32,
      'saturated_fat_g': 3.6,
      'sodium_mg': 600,
      'salt_g': 1.5,
    },
    serving: (9, 'chips', 28),
    ingredients: 'Potatoes, sunflower oil, salt.',
  ),
];

/// Ten everyday foods, three meals and a snack or two a day (different
/// breakfasts and dinners), adding up to about the 2000 kcal limit,
/// a little over on some days; a profile, and a weighing every few
/// mornings.
List<DemoEvent> foodDemoEvents(DemoPlan plan) {
  final events = <DemoEvent>[];
  final first = plan.firstDay;

  // The body details behind the calorie limit.
  events
    ..add(
      plan.event(plan.at(first, 7.9), bodyModuleName, 'profile_recorded', {
        'sex': 'female',
        'birth_year': 1992,
        'height_cm': 168,
      }),
    )
    ..add(
      plan.event(
        plan.at(first, 7.95),
        bodyModuleName,
        'energy_target_recorded',
        {'date': formatDate(first), 'energy_kcal': 2000},
      ),
    );

  final foodIds = <String, String>{};
  for (final food in _foods) {
    final serving = food.serving;
    final created = plan.event(
      plan.at(first, 7.97),
      foodModuleName,
      'food_created',
      {
        'name': food.name,
        'measured_in': food.measuredIn,
        'nutrients_per_100': Nutrients(food.per100).toJson(),
        if (serving != null)
          'serving': {
            'unit': serving.$2,
            'count': jsonNumber(serving.$1),
            'amount': jsonNumber(serving.$3),
          },
        if (food.ingredients != null) 'ingredients': food.ingredients,
      },
    );
    foodIds[food.name] = created.id;
    events.add(created);
  }

  /// A meal of [amount] (g or ml) of the food called [name], at [hours]
  /// on [day], logged a few minutes later.
  void eat(DateTime day, double hours, String name, double amount) {
    final food = _foods.firstWhere((food) => food.name == name);
    final eaten = plan.at(day, hours);
    final hour = eaten.hour.toString().padLeft(2, '0');
    final minute = eaten.minute.toString().padLeft(2, '0');
    events.add(
      plan.event(
        eaten.add(const Duration(minutes: 3)),
        foodModuleName,
        'food_entry_recorded',
        {
          'date': formatDate(day),
          'time': '$hour:$minute',
          'food_id': foodIds[name],
          'name': name,
          'amount': jsonNumber(amount),
          'measured_in': food.measuredIn,
          'nutrients': Nutrients(food.per100).scaledBy(amount / 100).toJson(),
        },
      ),
    );
  }

  for (final day in plan.days) {
    final ago = plan.daysAgo(day);
    // A few grams more or less each time, as when weighing for real.
    double some(double amount) =>
        (amount + plan.wobble(amount * 0.15)).roundToDouble();
    if (ago.isEven) {
      eat(day, 7.5, 'Rolled oats', some(80));
      eat(day, 7.52, 'Milk', some(250));
    } else {
      eat(day, 7.6, 'Greek yogurt', 150);
      eat(day, 7.62, 'Banana', some(120));
      eat(day, 7.64, 'Wholemeal bread', 72);
    }
    eat(day, 12.6, 'Rice, cooked', some(250));
    eat(day, 12.62, 'Chicken breast', some(160));
    eat(day, 12.64, 'Wholemeal bread', 36);
    if (plan.chance(0.3)) {
      eat(day, 16, 'Potato chips', 56);
    } else {
      eat(day, 16, 'Apple', some(180));
    }
    if (ago % 3 == 0) {
      eat(day, 19.2, 'Lentil soup', some(450));
      eat(day, 19.22, 'Wholemeal bread', 72);
    } else {
      eat(day, 19.2, 'Rice, cooked', some(220));
      eat(day, 19.22, 'Chicken breast', some(150));
    }
    if (plan.chance(0.5)) {
      eat(day, 21, 'Greek yogurt', 150);
    }

    // A weighing every third morning, slowly going down.
    if (ago % 3 == 0) {
      final kilograms = 68.5 - 0.04 * (plan.dayCount - ago) + plan.wobble(0.3);
      events.add(
        plan.event(plan.at(day, 7.1), bodyModuleName, 'weight_recorded', {
          'date': formatDate(day),
          'weight_kg': jsonNumber(roundToTenth(kilograms)),
        }),
      );
    }
  }
  return events;
}
