// SPDX-License-Identifier: GPL-3.0-or-later

/// How Ippo works out its body and nutrition numbers: every formula, and
/// where it comes from.
library;

import 'package:flutter_math_fork/flutter_math.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/section_card.dart';

/// One card per number Ippo works out: what it is, the formula typeset as
/// in a paper, what each letter means, why this formula, and the source.
/// So no number is a mystery: anyone can check it.
class SourcesScreen extends StatelessWidget {
  /// Creates the screen.
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How these are worked out')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: const [
          _Source(
            icon: Icons.local_fire_department,
            title: 'Basal metabolic rate (BMR)',
            what:
                'The energy your body uses in a day at complete rest, in '
                'kilocalories.',
            formulas: [
              r'\mathrm{BMR}_{\text{men}} = 10\,m + 6.25\,h - 5\,a + 5',
              r'\mathrm{BMR}_{\text{women}} = 10\,m + 6.25\,h - 5\,a - 161',
            ],
            symbols:
                'm: weight in kg (the latest you logged); h: height in cm; '
                'a: age in years (this year minus your year of birth).',
            why:
                'The Mifflin-St Jeor equation. A systematic review found it '
                'the most accurate of the common equations, within 10 % of '
                'the measured rate in most healthy adults, so dietitians use '
                'it most.',
            sources: [
              'Mifflin MD, St Jeor ST, Hill LA, Scott BJ, Daugherty SA, Koh '
                  'YO. A new predictive equation for resting energy '
                  'expenditure in healthy individuals. Am J Clin Nutr. '
                  '1990;51(2):241-247. doi:10.1093/ajcn/51.2.241',
              'Frankenfield D, Roth-Yousey L, Compher C. Comparison of '
                  'predictive equations for resting metabolic rate in '
                  'healthy nonobese and obese adults: a systematic review. '
                  'J Am Diet Assoc. 2005;105(5):775-789. '
                  'doi:10.1016/j.jada.2005.02.005',
            ],
          ),
          _Source(
            icon: Icons.directions_run,
            title: 'Energy used in a day',
            what: 'Your BMR plus what moving about adds.',
            formulas: [r'E = \mathrm{BMR} \times \mathrm{PAL}'],
            symbols:
                'PAL: physical activity level: 1.2 for little exercise, '
                '1.375 light, 1.55 moderate, 1.725 hard.',
            why:
                'These four factors are a widely used rule of thumb, not the '
                'result of one study. For comparison, the FAO, WHO and UNU '
                'describe ways of life with activity levels from 1.40 to '
                '1.69 (sedentary or light), 1.70 to 1.99 (active) and 2.00 '
                'to 2.40 (vigorous). Treat the result as an estimate.',
            sources: [
              'FAO/WHO/UNU. Human energy requirements: report of a joint '
                  'FAO/WHO/UNU expert consultation. FAO Food and Nutrition '
                  'Technical Report Series 1. Rome: FAO; 2004.',
            ],
          ),
          _Source(
            icon: Icons.restaurant,
            title: 'Daily amounts of nutrients',
            what:
                'The bars on the Food page and on Home: how much of an '
                'average adult\'s daily amount you have eaten.',
            formulas: [
              r'R = R_{2000} \times \frac{E_{\text{limit}}}{2000}',
              r'R_{\text{protein}} = 0.83\,\tfrac{\text{g}}{\text{kg}} '
                  r'\times m',
            ],
            symbols:
                'R_2000: the EU reference intake for 2000 kcal a day (fat '
                '70 g, saturates 20 g, carbohydrate 260 g, sugars 90 g, '
                'protein 50 g, salt 6 g). With a calorie limit E_limit, fat, '
                'saturates, carbohydrate and sugars scale with it. With a '
                'weight m, protein follows it. Vitamins and minerals use the '
                'EU nutrient reference values; fibre 25 g; cholesterol '
                '300 mg and added sugars 50 g (US daily values, as the EU '
                'has none).',
            why:
                'These are averages for adults, used on food labels across '
                'the EU, not targets for any one person.',
            sources: [
              'Regulation (EU) No 1169/2011 on the provision of food '
                  'information to consumers, Annex XIII (reference intakes '
                  'and nutrient reference values).',
              'EFSA Panel on Dietetic Products, Nutrition and Allergies. '
                  'Scientific Opinion on Dietary Reference Values for '
                  'protein. EFSA Journal. 2012;10(2):2557. '
                  'doi:10.2903/j.efsa.2012.2557',
              'EFSA Panel on Dietetic Products, Nutrition and Allergies. '
                  'Scientific Opinion on Dietary Reference Values for '
                  'carbohydrates and dietary fibre. EFSA Journal. '
                  '2010;8(3):1462. doi:10.2903/j.efsa.2010.1462',
              'US Code of Federal Regulations, 21 CFR 101.9(c), daily '
                  'values for cholesterol and added sugars.',
            ],
          ),
          _Source(
            icon: Icons.science_outlined,
            title: 'Salt and energy units',
            what: 'How label values are turned into the units Ippo keeps.',
            formulas: [
              r'\text{salt} = 2.5 \times \text{sodium}',
              r'1\ \text{kcal} = 4.184\ \text{kJ}',
            ],
            symbols:
                'A label that gives only sodium (as in the US) gets salt '
                'worked out from it; a label in kJ only, kilocalories.',
            why: 'Both are the definitions used on EU food labels.',
            sources: [
              'Regulation (EU) No 1169/2011, Annex I, point 11 (salt), and '
                  'Annex XIV (conversion factors for energy).',
            ],
          ),
        ],
      ),
    );
  }
}

/// One number: what it is, its formulas, its symbols, why, and sources.
class _Source extends StatelessWidget {
  const _Source({
    required this.icon,
    required this.title,
    required this.what,
    required this.formulas,
    required this.symbols,
    required this.why,
    required this.sources,
  });

  final IconData icon;
  final String title;
  final String what;

  /// The formulas, in LaTeX.
  final List<String> formulas;
  final String symbols;
  final String why;
  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return SectionCard(
      children: [
        CardHeader(icon: icon, title: title),
        Text(what, style: textTheme.bodyMedium),
        const SizedBox(height: Spacing.medium),
        // The formulas, typeset, each on a soft panel and scrolling
        // sideways if too wide for the screen.
        for (final formula in formulas)
          Container(
            margin: const EdgeInsets.only(bottom: Spacing.small),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.medium,
              vertical: Spacing.small,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                formula,
                textStyle: textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
        const SizedBox(height: Spacing.tight),
        NoteText(symbols),
        const SizedBox(height: Spacing.small),
        Text(why, style: textTheme.bodyMedium),
        const SizedBox(height: Spacing.medium),
        Text(
          sources.length == 1 ? 'Source' : 'Sources',
          style: textTheme.labelMedium?.copyWith(color: colors.primary),
        ),
        const SizedBox(height: Spacing.tight),
        for (final source in sources)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.tight),
            child: SelectableText(
              source,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
