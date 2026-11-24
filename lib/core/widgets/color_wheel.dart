// SPDX-License-Identifier: GPL-3.0-or-later

/// Picking any color from a wheel, for when none of the preset color
/// circles is right.
library;

import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'color_circles.dart';

/// Opens a window with a color wheel, starting at [initial]. Returns the
/// chosen color, or null if canceled. Its preview shows the color as
/// [asShown] turns it, as the app will show it.
Future<Color?> showColorWheel(
  BuildContext context, {
  required Color initial,
  required Color Function(Color) asShown,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorWheelDialog(initial: initial, asShown: asShown),
  );
}

/// The last circle in a row of color circles: a rainbow that opens the
/// color wheel. When [color] (a color not among the presets) is the
/// chosen one, it shows that color with a tick instead.
class CustomColorCircle extends StatelessWidget {
  /// Creates the circle.
  const CustomColorCircle({
    super.key,
    required this.color,
    required this.purpose,
    required this.onPicked,
    required this.asShown,
  });

  /// The chosen color if it is a custom one, or null.
  final Color? color;

  /// What the color is for, read out by screen readers.
  final String purpose;

  /// Called with the color picked on the wheel.
  final ValueChanged<Color> onPicked;

  /// Turns a picked color into the one the app shows (see
  /// [accentAsShown] and [habitColorAsShown]), so the circle and the
  /// wheel's preview match what the app will look like.
  final Color Function(Color) asShown;

  Future<void> _open(BuildContext context) async {
    final picked = await showColorWheel(
      context,
      initial: color ?? Theme.of(context).colorScheme.primary,
      asShown: asShown,
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = color;
    // The chosen color as the app shows it.
    final chosen = picked == null ? null : asShown(picked);
    return Semantics(
      label: 'Other $purpose: pick from a color wheel',
      selected: chosen != null,
      button: true,
      child: ColorSwatchButton(
        isSelected: chosen != null,
        onTap: () => _open(context),
        // A rainbow until a custom color is chosen.
        swatch: chosen == null
            ? const BoxDecoration(gradient: SweepGradient(colors: _hueColors))
            : BoxDecoration(color: chosen),
        mark: Icon(
          chosen == null ? Icons.palette_outlined : Icons.check,
          size: 20,
          color: chosen == null || _isDark(chosen)
              ? Colors.white
              : Colors.black,
        ),
      ),
    );
  }
}

/// Whether [color] is dark enough to need white marks on it.
bool _isDark(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.dark;

/// Every hue around the wheel, red at the start and the end.
const List<Color> _hueColors = [
  Color(0xFFFF0000),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF00FFFF),
  Color(0xFF0000FF),
  Color(0xFFFF00FF),
  Color(0xFFFF0000),
];

/// How wide the wheel is: as wide as fits in a dialog on a small phone.
const double _wheelSide = 220;

/// The wheel: hue goes around it, and strength (saturation) out from
/// the pale center to the rim. A slider below sets the brightness.
class _ColorWheelDialog extends StatefulWidget {
  const _ColorWheelDialog({required this.initial, required this.asShown});

  final Color initial;

  /// Turns the picked color into the one the app shows, for the
  /// preview.
  final Color Function(Color) asShown;

  @override
  State<_ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<_ColorWheelDialog> {
  late HSVColor _color = HSVColor.fromColor(widget.initial);

  /// Picks the color under [position], a point in a wheel [side] wide.
  /// A point outside the rim picks the color at the rim.
  void _pickAt(Offset position, double side) {
    final radius = side / 2;
    final fromCenter = position - Offset(radius, radius);
    // The angle, measured clockwise from the right, as the wheel is
    // drawn; from 0 to 360 degrees.
    final degrees = (atan2(fromCenter.dy, fromCenter.dx) * 180 / pi) % 360;
    final saturation = min(fromCenter.distance / radius, 1.0);
    setState(() {
      _color = _color.withHue(degrees).withSaturation(saturation);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _color.toColor();
    return AlertDialog(
      title: const Text('Pick a color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A fixed size: dialogs measure their content first, which a
          // size taken from the space available would not allow.
          GestureDetector(
            onPanDown: (details) => _pickAt(details.localPosition, _wheelSide),
            onPanUpdate: (details) =>
                _pickAt(details.localPosition, _wheelSide),
            child: SizedBox.square(
              dimension: _wheelSide,
              child: CustomPaint(painter: _WheelPainter(_color)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.brightness_6_outlined),
              Expanded(
                child: Slider(
                  value: _color.value,
                  min: 0.2,
                  onChanged: (value) =>
                      setState(() => _color = _color.withValue(value)),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                // As the app will show it, not the raw color.
                decoration: BoxDecoration(
                  color: widget.asShown(color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                accentColorToHex(color),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(color),
          child: const Text('Choose'),
        ),
      ],
    );
  }
}

/// Draws the wheel at the chosen brightness, and a ring where [color]
/// is on it.
class _WheelPainter extends CustomPainter {
  _WheelPainter(this.color);

  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final circle = Rect.fromCircle(center: center, radius: radius);
    // Hues around the rim...
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(colors: _hueColors).createShader(circle),
    );
    // ...fading to white at the center...
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        ).createShader(circle),
    );
    // ...and darkened by the brightness slider.
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Color.fromRGBO(0, 0, 0, 1 - color.value),
    );
    // The ring marking the chosen color.
    final angle = color.hue * pi / 180;
    final marker =
        center + Offset(cos(angle), sin(angle)) * radius * color.saturation;
    canvas
      ..drawCircle(
        marker,
        10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white,
      )
      ..drawCircle(
        marker,
        12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black54,
      );
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) => oldDelegate.color != color;
}
