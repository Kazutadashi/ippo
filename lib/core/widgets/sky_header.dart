// SPDX-License-Identifier: GPL-3.0-or-later

/// The landscape at the top of the home screen: mountains under a sky
/// that follows the time of day, like the app's icon.
library;

import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// The four skies, by time of day.
enum SkyPhase {
  /// Early morning: a warm horizon and a low sun.
  dawn,

  /// The day: a blue sky and a high sun.
  day,

  /// The evening: a darkening sky, the moon rising, the first stars.
  dusk,

  /// The night: a deep sky, the moon and many stars.
  night;

  /// The sky for the hour of [moment].
  static SkyPhase of(DateTime moment) {
    final hour = moment.hour;
    if (hour >= 5 && hour < 8) {
      return dawn;
    }
    if (hour >= 8 && hour < 17) {
      return day;
    }
    if (hour >= 17 && hour < 21) {
      return dusk;
    }
    return night;
  }
}

/// The colours of one sky and its mountains.
class _Palette {
  const _Palette({
    required this.sky,
    required this.far,
    required this.lit,
    required this.shade,
    required this.litBack,
    required this.shadeBack,
    required this.snow,
    required this.near,
    required this.light,
    required this.isSun,
    required this.starCount,
  });

  /// The sky from top to horizon.
  final List<Color> sky;

  /// The far range, hazy.
  final Color far;

  /// The front peak's lit and shaded faces.
  final Color lit;
  final Color shade;

  /// The peak behind it, a little fainter.
  final Color litBack;
  final Color shadeBack;

  /// The snow on the tallest peaks.
  final Color snow;

  /// The nearest ridge, darkest.
  final Color near;

  /// The sun or moon.
  final Color light;

  /// Whether [light] is the sun (else the moon, with craters).
  final bool isSun;

  /// How many stars show.
  final int starCount;
}

const Map<SkyPhase, _Palette> _palettes = {
  SkyPhase.dawn: _Palette(
    sky: [Color(0xFF3C5A86), Color(0xFF8FA7C9), Color(0xFFF0BE94)],
    far: Color(0xFF9DAFC6),
    lit: Color(0xFF8AA6AE),
    shade: Color(0xFF62818C),
    litBack: Color(0xFF7D99A6),
    shadeBack: Color(0xFF5E7B88),
    snow: Color(0xFFF7EEE4),
    near: Color(0xFF465F6B),
    light: Color(0xFFFFD9A0),
    isSun: true,
    starCount: 0,
  ),
  SkyPhase.day: _Palette(
    sky: [Color(0xFF3F78B5), Color(0xFF7FAEDD), Color(0xFFCFE3F2)],
    far: Color(0xFFA9C3D9),
    lit: Color(0xFF8CB0B8),
    shade: Color(0xFF5F8794),
    litBack: Color(0xFF9BBAC4),
    shadeBack: Color(0xFF6E93A0),
    snow: Color(0xFFFFFFFF),
    near: Color(0xFF4A6B76),
    light: Color(0xFFFFF4D6),
    isSun: true,
    starCount: 0,
  ),
  SkyPhase.dusk: _Palette(
    sky: [Color(0xFF141F33), Color(0xFF2E3B5E), Color(0xFF8A6A7E)],
    far: Color(0xFF4B5675),
    lit: Color(0xFF6B8794),
    shade: Color(0xFF465F6E),
    litBack: Color(0xFF5A7584),
    shadeBack: Color(0xFF3F5666),
    snow: Color(0xFFE6E2EA),
    near: Color(0xFF26364A),
    light: Color(0xFFE9E2CC),
    isSun: false,
    starCount: 18,
  ),
  SkyPhase.night: _Palette(
    sky: [Color(0xFF0B1424), Color(0xFF17243B), Color(0xFF2A3A57)],
    far: Color(0xFF2D3B55),
    lit: Color(0xFF52707E),
    shade: Color(0xFF354F5E),
    litBack: Color(0xFF425E6D),
    shadeBack: Color(0xFF2E4554),
    snow: Color(0xFFD5DEE4),
    near: Color(0xFF1A2A38),
    light: Color(0xFFE9E2CC),
    isSun: false,
    starCount: 36,
  ),
};

/// The landscape: the sky for [phase], its sun or moon, stars at dusk
/// and night, and three layers of mountains that fade into the page
/// below. Decoration only, so screen readers skip it.
class SkyHeader extends StatelessWidget {
  /// Creates the landscape.
  const SkyHeader({
    super.key,
    required this.phase,
    required this.height,
    required this.clearTop,
  });

  /// Which sky to draw.
  final SkyPhase phase;

  /// How tall it is.
  final double height;

  /// How much of the top is kept as open sky, for the status bar and the
  /// greeting: the mountains rise only below it.
  final double clearTop;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SkyPainter(
            palette: _palettes[phase]!,
            background: Theme.of(context).scaffoldBackgroundColor,
            clearTop: clearTop,
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.palette,
    required this.background,
    required this.clearTop,
  });

  final _Palette palette;
  final Color background;
  final double clearTop;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    // Heights in the landscape, from 0.3 (the highest summit can reach)
    // to 1 (the bottom), placed in the land below the clear top.
    double y(double f) => clearTop + (h - clearTop) * ((f - 0.3) / 0.7);

    // The sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.sky,
        ).createShader(rect),
    );

    // The sun or moon, low in the sky, to the right of the peaks.
    final lightCentre = Offset(w * 0.72, y(palette.isSun ? 0.56 : 0.44));
    final radius = (h - clearTop) * 0.17;
    _stars(canvas, size, avoid: lightCentre, avoidRadius: radius * 1.8);
    _sunOrMoon(canvas, lightCentre, radius);

    // The far range: a long, soft, jagged line, hazy with distance.
    _fill(canvas, palette.far, [
      Offset(0, y(0.70)),
      Offset(w * 0.08, y(0.62)),
      Offset(w * 0.16, y(0.66)),
      Offset(w * 0.27, y(0.56)),
      Offset(w * 0.36, y(0.63)),
      Offset(w * 0.47, y(0.58)),
      Offset(w * 0.58, y(0.66)),
      Offset(w * 0.68, y(0.60)),
      Offset(w * 0.80, y(0.67)),
      Offset(w * 0.90, y(0.59)),
      Offset(w, y(0.65)),
      Offset(w, h),
      Offset(0, h),
    ]);

    // The peak behind, then the tall front peak, each with a lit face
    // and a shaded face, and snow on top.
    _peak(
      canvas,
      top: Offset(w * 0.62, y(0.50)),
      left: w * 0.40,
      right: w * 0.88,
      base: h,
      lit: palette.litBack,
      shade: palette.shadeBack,
      snowDepth: (h - clearTop) * 0.10,
    );
    _peak(
      canvas,
      top: Offset(w * 0.30, y(0.36)),
      left: -w * 0.02,
      right: w * 0.66,
      base: h,
      lit: palette.lit,
      shade: palette.shade,
      snowDepth: (h - clearTop) * 0.14,
    );
    _peak(
      canvas,
      top: Offset(w * 0.90, y(0.58)),
      left: w * 0.76,
      right: w * 1.06,
      base: h,
      lit: palette.litBack,
      shade: palette.shadeBack,
      snowDepth: 0,
    );

    // The nearest ridge, rolling.
    final near = Path()
      ..moveTo(0, y(0.86))
      ..quadraticBezierTo(w * 0.14, y(0.78), w * 0.30, y(0.84))
      ..quadraticBezierTo(w * 0.50, y(0.92), w * 0.66, y(0.82))
      ..quadraticBezierTo(w * 0.82, y(0.74), w, y(0.84))
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(near, Paint()..color = palette.near);

    // Fade into the page, so the cards below start on plain ground.
    final fade = Rect.fromLTRB(0, y(0.68), w, h);
    canvas.drawRect(
      fade,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [background.withValues(alpha: 0), background],
        ).createShader(fade),
    );
  }

  /// Scattered stars of different sizes and brightness, the same every
  /// time (a fixed seed), in the upper sky, none behind the moon.
  void _stars(
    Canvas canvas,
    Size size, {
    required Offset avoid,
    required double avoidRadius,
  }) {
    final random = Random(7);
    final paint = Paint()..color = const Color(0xFFF4F1E8);
    var drawn = 0;
    while (drawn < palette.starCount) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height * 0.55,
      );
      final radius = 0.4 + random.nextDouble() * random.nextDouble() * 1.2;
      final brightness = 0.25 + random.nextDouble() * 0.6;
      if ((point - avoid).distance < avoidRadius) {
        continue;
      }
      drawn++;
      paint.color = paint.color.withValues(alpha: brightness);
      canvas.drawCircle(point, radius, paint);
      // A few of the brightest get a faint glow.
      if (radius > 1.1) {
        canvas.drawCircle(
          point,
          radius * 3,
          Paint()..color = paint.color.withValues(alpha: brightness * 0.12),
        );
      }
    }
  }

  /// The sun (a soft glow) or the moon (a glow, a shade for roundness and
  /// faint craters for texture).
  void _sunOrMoon(Canvas canvas, Offset centre, double radius) {
    final light = palette.light;
    canvas.drawCircle(
      centre,
      radius * 2.0,
      Paint()..color = light.withValues(alpha: 0.07),
    );
    canvas.drawCircle(
      centre,
      radius * 1.45,
      Paint()..color = light.withValues(alpha: 0.12),
    );
    canvas.drawCircle(centre, radius, Paint()..color = light);
    if (palette.isSun) {
      return;
    }
    final shade = Paint()
      ..color = const Color(0xFFB9B29C).withValues(alpha: 0.2);
    canvas.drawCircle(
      centre + Offset(radius * 0.25, radius * 0.2),
      radius * 0.94,
      shade,
    );
    const craters = [
      (-0.35, -0.30, 0.20, 0.16),
      (0.30, -0.40, 0.12, 0.13),
      (0.34, 0.18, 0.25, 0.12),
      (-0.18, 0.36, 0.14, 0.14),
      (-0.55, 0.10, 0.09, 0.12),
      (0.05, -0.05, 0.07, 0.10),
    ];
    for (final (dx, dy, size, opacity) in craters) {
      canvas.drawCircle(
        centre + Offset(dx * radius, dy * radius),
        size * radius,
        Paint()..color = const Color(0xFF8F8A78).withValues(alpha: opacity),
      );
    }
  }

  /// A peak from [left] to [right] with its summit at [top]: the left
  /// face lit, the right face shaded, and, with [snowDepth], a jagged
  /// snow cap.
  void _peak(
    Canvas canvas, {
    required Offset top,
    required double left,
    required double right,
    required double base,
    required Color lit,
    required Color shade,
    required double snowDepth,
  }) {
    _fill(canvas, lit, [top, Offset(top.dx, base), Offset(left, base)]);
    _fill(canvas, shade, [top, Offset(right, base), Offset(top.dx, base)]);
    if (snowDepth == 0) {
      return;
    }
    // Where the snow line meets each slope.
    final leftSlope = (top.dx - left) / (base - top.dy);
    final rightSlope = (right - top.dx) / (base - top.dy);
    final y = top.dy + snowDepth;
    final leftEdge = top.dx - leftSlope * snowDepth;
    final rightEdge = top.dx + rightSlope * snowDepth;
    _fill(canvas, palette.snow, [
      top,
      Offset(rightEdge, y),
      Offset(top.dx + (rightEdge - top.dx) * 0.45, y - snowDepth * 0.22),
      Offset(top.dx, y + snowDepth * 0.08),
      Offset(top.dx - (top.dx - leftEdge) * 0.45, y - snowDepth * 0.25),
      Offset(leftEdge, y),
    ]);
  }

  void _fill(Canvas canvas, Color color, List<Offset> points) {
    final path = Path()..addPolygon(points, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.palette != palette ||
      old.background != background ||
      old.clearTop != clearTop;
}
