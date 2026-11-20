// SPDX-License-Identifier: GPL-3.0-or-later

/// How Ippo works out its body and nutrition numbers: every formula, and
/// where it comes from.
library;

import 'package:flutter_math_fork/flutter_math.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/section_card.dart';

/// One symbol in a formula: how it is written (LaTeX), what it means,
/// and its unit.
typedef _Symbol = ({String tex, String meaning, String unit});

/// One card per number Ippo works out, each built from the same parts,
/// one below the other, so it reads like a page of a textbook rather than
/// a block of text:
///
/// 1. what the number is, in one sentence;
/// 2. the formulas, typeset;
/// 3. a table of the symbols: each written as in the formula, its
///    meaning, and its unit;
/// 4. a table of fixed values, when the formula uses some;
/// 5. why this formula, in a highlighted box;
/// 6. the sources, numbered.
class SourcesScreen extends StatelessWidget {
  /// Creates the screen.
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How these are worked out')),
      body: ListView(
        padding: belowNavigationBar(
          context,
          const EdgeInsets.fromLTRB(12, 4, 12, 24),
        ),
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
            symbols: [
              (
                tex: r'\mathit{m}',
                meaning: 'Weight, the latest you logged',
                unit: 'kg',
              ),
              (tex: r'\mathit{h}', meaning: 'Height', unit: 'cm'),
              (
                tex: r'\mathit{a}',
                meaning: 'Age: this year minus your year of birth',
                unit: 'years',
              ),
            ],
            why:
                'This is the Mifflin-St Jeor equation. A systematic review '
                'of the common equations found it the most accurate: within '
                '10 % of the measured rate in most healthy adults. That is '
                'why dietitians use it most.',
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
            what: 'Your BMR plus what moving about adds, in kilocalories.',
            formulas: [r'E = \mathrm{BMR} \times \mathrm{PAL}'],
            symbols: [
              (
                tex: r'\mathrm{BMR}',
                meaning: 'Basal metabolic rate, above',
                unit: 'kcal',
              ),
              (
                tex: r'\mathrm{PAL}',
                meaning: 'Physical activity level, from the table below',
                unit: '–',
              ),
            ],
            valuesTitle: 'Activity levels',
            values: [
              ('Little or no exercise', '1.2'),
              ('Light, 1–3 days a week', '1.375'),
              ('Moderate, 3–5 days a week', '1.55'),
              ('Hard, 6–7 days a week', '1.725'),
            ],
            why:
                'These four levels are a widely used rule of thumb, not the '
                'result of one study, so treat the result as an estimate. '
                'For comparison, the FAO, WHO and UNU give 1.40–1.69 for a '
                'sedentary or light way of life, 1.70–1.99 for an active '
                'one and 2.00–2.40 for a vigorous one.',
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
              r'R_{\text{protein}} = 0.83 \times m',
            ],
            symbols: [
              (
                tex: r'R',
                meaning: 'Your daily amount of a nutrient',
                unit: 'g',
              ),
              (
                tex: r'R_{2000}',
                meaning: 'Its amount for 2000 kcal a day, below',
                unit: 'g',
              ),
              (
                tex: r'E_{\text{limit}}',
                meaning: 'Your daily calorie limit, if set (else 2000)',
                unit: 'kcal',
              ),
              (
                tex: r'\mathit{m}',
                meaning: 'Your weight, if logged',
                unit: 'kg',
              ),
            ],
            valuesTitle: 'Amounts for 2000 kcal a day',
            values: [
              ('Fat (scales with the limit)', '70 g'),
              ('Saturates (scales)', '20 g'),
              ('Carbohydrate (scales)', '260 g'),
              ('Sugars (scales)', '90 g'),
              ('Protein (or 0.83 g per kg)', '50 g'),
              ('Fibre', '25 g'),
              ('Salt', '6 g'),
              ('Cholesterol', '300 mg'),
              ('Added sugars (scales)', '50 g'),
            ],
            why:
                'These are the amounts on food labels across the EU: '
                'averages for adults, not targets for any one person. '
                'Vitamins and minerals use the EU nutrient reference '
                'values. The EU has none for fibre, cholesterol and added '
                'sugars, so those come from EFSA and the US.',
            sources: [
              'Regulation (EU) No 1169/2011 on the provision of food '
                  'information to consumers, Annex XIII.',
              'EFSA Panel on Dietetic Products, Nutrition and Allergies. '
                  'Scientific Opinion on Dietary Reference Values for '
                  'protein. EFSA Journal. 2012;10(2):2557. '
                  'doi:10.2903/j.efsa.2012.2557',
              'EFSA Panel on Dietetic Products, Nutrition and Allergies. '
                  'Scientific Opinion on Dietary Reference Values for '
                  'carbohydrates and dietary fibre. EFSA Journal. '
                  '2010;8(3):1462. doi:10.2903/j.efsa.2010.1462',
              'US Code of Federal Regulations, 21 CFR 101.9(c): daily '
                  'values for cholesterol and added sugars.',
            ],
          ),
          _Source(
            icon: Icons.science_outlined,
            title: 'Salt and energy on labels',
            what: 'How label values are turned into the units Ippo keeps.',
            formulas: [
              r'\text{salt} = 2.5 \times \text{sodium}',
              r'1\ \text{kcal} = 4.184\ \text{kJ}',
            ],
            symbols: [],
            why:
                'A label that gives only sodium (as in the US) gets salt '
                'worked out from it, and a label in kJ only, kilocalories. '
                'Both are the definitions used on EU food labels.',
            sources: [
              'Regulation (EU) No 1169/2011, Annex I, point 11 (salt), and '
                  'Annex XIV (energy).',
            ],
          ),
        ],
      ),
    );
  }
}

/// One number: its parts, one below the other.
class _Source extends StatelessWidget {
  const _Source({
    required this.icon,
    required this.title,
    required this.what,
    required this.formulas,
    required this.symbols,
    required this.why,
    required this.sources,
    this.valuesTitle,
    this.values = const [],
  });

  final IconData icon;
  final String title;
  final String what;

  /// The formulas, in LaTeX.
  final List<String> formulas;

  /// The symbols in the formulas, explained.
  final List<_Symbol> symbols;

  /// The title of [values], such as "Activity levels".
  final String? valuesTitle;

  /// Fixed values the formula uses: a name and its value.
  final List<(String, String)> values;
  final String why;
  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final valuesTitle = this.valuesTitle;
    return SectionCard(
      children: [
        CardHeader(icon: icon, title: title),
        Text(what, style: textTheme.bodyLarge),
        const SizedBox(height: Spacing.medium),
        for (final formula in formulas) _FormulaPanel(tex: formula),
        if (symbols.isNotEmpty) ...[
          const SizedBox(height: Spacing.small),
          _Heading('Where'),
          _SymbolTable(symbols: symbols),
        ],
        if (valuesTitle != null) ...[
          const SizedBox(height: Spacing.medium),
          _Heading(valuesTitle),
          _ValuesTable(values: values),
        ],
        const SizedBox(height: Spacing.medium),
        _WhyBox(text: why),
        const SizedBox(height: Spacing.medium),
        _Heading(sources.length == 1 ? 'Source' : 'Sources'),
        for (var index = 0; index < sources.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.small),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '[${index + 1}]',
                    style: textTheme.bodySmall?.copyWith(color: colors.primary),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    sources[index],
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A small heading in the accent colour, above a table or the sources.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.small),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// A formula, typeset, on a soft panel; shrunk to fit if it is too wide
/// for the screen.
class _FormulaPanel extends StatelessWidget {
  const _FormulaPanel({required this.tex});

  final String tex;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Spacing.small),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.medium,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      // Too wide for the screen: shrunk to fit, so it is read whole.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Math.tex(
          tex,
          textStyle: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: colors.onSurface),
        ),
      ),
    );
  }
}

/// The symbols as a table: each written as in the formula, what it
/// means, and its unit, with thin lines between rows.
class _SymbolTable extends StatelessWidget {
  const _SymbolTable({required this.symbols});

  final List<_Symbol> symbols;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(color: colors.outlineVariant),
      ),
      children: [
        for (final symbol in symbols)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
                child: Math.tex(
                  symbol.tex,
                  textStyle: textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(symbol.meaning, style: textTheme.bodyMedium),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  symbol.unit,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Fixed values as a table: a name on the left, its value at the right.
class _ValuesTable extends StatelessWidget {
  const _ValuesTable({required this.values});

  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Table(
      columnWidths: const {0: FlexColumnWidth(), 1: IntrinsicColumnWidth()},
      border: TableBorder(
        horizontalInside: BorderSide(color: colors.outlineVariant),
      ),
      children: [
        for (final (name, value) in values)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(name, style: textTheme.bodyMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Text(value, style: textTheme.titleSmall),
              ),
            ],
          ),
      ],
    );
  }
}

/// Why this formula, in a box with an accent line on its left and a
/// light bulb, so it stands apart from the facts above it.
class _WhyBox extends StatelessWidget {
  const _WhyBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    // Rounded corners come from the clip: a border on one side only
    // cannot have rounded corners of its own.
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.10),
          border: Border(left: BorderSide(color: colors.primary, width: 4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, size: 20, color: colors.primary),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Why this formula', style: textTheme.titleSmall),
                  const SizedBox(height: Spacing.tight),
                  Text(text, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
