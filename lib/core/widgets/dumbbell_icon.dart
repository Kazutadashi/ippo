// SPDX-License-Identifier: GPL-3.0-or-later

/// A dumbbell icon with thick plates, drawn by hand.
library;

import 'package:material_ui/material_ui.dart';

/// A level dumbbell: a short bar with two thick plates on each side, a
/// big one inside and a smaller one outside. Material's own dumbbell has
/// thin plates and stands at an angle, which reads oddly at small sizes.
///
/// It takes its size and color from the surrounding [IconTheme], like
/// an [Icon], so it can go anywhere an icon goes: the tab bar, a tile, a
/// card header.
class DumbbellIcon extends StatelessWidget {
  /// Creates the icon; [size] and [color] override the [IconTheme].
  const DumbbellIcon({super.key, this.size, this.color});

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
        child: CustomPaint(painter: _DumbbellPainter(paint)),
      ),
    );
  }
}

class _DumbbellPainter extends CustomPainter {
  _DumbbellPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 24 by 24 grid, like Material icons, then scaled.
    final scale = size.width / 24;
    canvas.scale(scale);
    final paint = Paint()..color = color;
    RRect part(double left, double top, double width, double height) {
      return RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, height),
        const Radius.circular(1.2),
      );
    }

    // The bar.
    canvas.drawRect(const Rect.fromLTWH(6, 10.75, 12, 2.5), paint);
    // Big inner plates, then small outer ones, the same on each side.
    canvas.drawRRect(part(5, 5, 3.5, 14), paint);
    canvas.drawRRect(part(15.5, 5, 3.5, 14), paint);
    canvas.drawRRect(part(1.5, 7.5, 3, 9), paint);
    canvas.drawRRect(part(19.5, 7.5, 3, 9), paint);
  }

  @override
  bool shouldRepaint(_DumbbellPainter oldDelegate) =>
      oldDelegate.color != color;
}
