// SPDX-License-Identifier: GPL-3.0-or-later

/// A crescent moon with a small star, drawn by hand.
library;

import 'package:material_ui/material_ui.dart';

/// A full, round crescent moon with a small four-pointed star beside
/// it: the icon for sleep. Material's moons are thin or lopsided at small
/// sizes; this one is cut from two circles, so its curves are even.
///
/// It takes its size and color from the surrounding [IconTheme], like
/// an [Icon], so it can go anywhere an icon goes.
class MoonIcon extends StatelessWidget {
  /// Creates the icon; [size] and [color] override the [IconTheme].
  const MoonIcon({super.key, this.size, this.color});

  /// The width and height, or null for the icon theme's size.
  final double? size;

  /// The color, or null for the icon theme's color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final side = size ?? iconTheme.size ?? 24;
    final paint = color ?? iconTheme.color ?? const Color(0xFF000000);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: side,
        child: CustomPaint(painter: _MoonPainter(paint)),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 24 by 24 grid, like Material icons, then scaled.
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    // The crescent: a disc with an offset disc cut out of its upper
    // right, which leaves a thick, even curve.
    final moon = Path()
      ..addOval(Rect.fromCircle(center: const Offset(10.5, 13), radius: 8.5));
    final shadow = Path()
      ..addOval(Rect.fromCircle(center: const Offset(15.5, 8.5), radius: 7));
    canvas.drawPath(
      Path.combine(PathOperation.difference, moon, shadow),
      paint,
    );

    // A small four-pointed star in the cut-out, as in a night sky.
    const center = Offset(19, 6);
    const reach = 2.8;
    const waist = 0.7;
    final star = Path()
      ..moveTo(center.dx, center.dy - reach)
      ..lineTo(center.dx + waist, center.dy - waist)
      ..lineTo(center.dx + reach, center.dy)
      ..lineTo(center.dx + waist, center.dy + waist)
      ..lineTo(center.dx, center.dy + reach)
      ..lineTo(center.dx - waist, center.dy + waist)
      ..lineTo(center.dx - reach, center.dy)
      ..lineTo(center.dx - waist, center.dy - waist)
      ..close();
    canvas.drawPath(star, paint);
  }

  @override
  bool shouldRepaint(_MoonPainter oldDelegate) => oldDelegate.color != color;
}
