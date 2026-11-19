// SPDX-License-Identifier: GPL-3.0-or-later

/// The landscape at the top of the home screen: mountains under a sky
/// that follows the time of day, like the app's icon.
///
/// The mountains are made up fresh for each day (the date is the seed of
/// a random number generator), so Home looks a little different every
/// day, and the same all through one day.
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
    required this.mid,
    required this.shade,
    required this.snow,
    required this.near,
    required this.trees,
    required this.light,
    required this.isSun,
    required this.starCount,
    required this.mist,
  });

  /// The sky from top to horizon.
  final List<Color> sky;

  /// The far range, hazy with distance.
  final Color far;

  /// The middle range's sunlit faces.
  final Color mid;

  /// Its faces turned away from the light.
  final Color shade;

  /// The snow on its tops.
  final Color snow;

  /// The near ridge, darkest.
  final Color near;

  /// The pines along the near ridge.
  final Color trees;

  /// The sun or moon.
  final Color light;

  /// Whether [light] is the sun (else the moon, with craters).
  final bool isSun;

  /// How many stars show.
  final int starCount;

  /// Whether low mist lies in the valleys.
  final bool mist;
}

const Map<SkyPhase, _Palette> _palettes = {
  SkyPhase.dawn: _Palette(
    sky: [Color(0xFF3C5A86), Color(0xFF8FA7C9), Color(0xFFF0BE94)],
    far: Color(0xFF9DAFC6),
    mid: Color(0xFF7E9AA8),
    shade: Color(0xFF5B7684),
    snow: Color(0xFFF7EEE4),
    near: Color(0xFF3F5864),
    trees: Color(0xFF2F4650),
    light: Color(0xFFFFD9A0),
    isSun: true,
    starCount: 0,
    mist: true,
  ),
  SkyPhase.day: _Palette(
    sky: [Color(0xFF3F78B5), Color(0xFF7FAEDD), Color(0xFFCFE3F2)],
    far: Color(0xFFA9C3D9),
    mid: Color(0xFF86A9B4),
    shade: Color(0xFF5E8592),
    snow: Color(0xFFFFFFFF),
    near: Color(0xFF46666F),
    trees: Color(0xFF34525B),
    light: Color(0xFFFFF4D6),
    isSun: true,
    starCount: 0,
    mist: false,
  ),
  SkyPhase.dusk: _Palette(
    sky: [Color(0xFF141F33), Color(0xFF2E3B5E), Color(0xFF8A6A7E)],
    far: Color(0xFF4B5675),
    mid: Color(0xFF5F7A89),
    shade: Color(0xFF3F5666),
    snow: Color(0xFFE6E2EA),
    near: Color(0xFF223246),
    trees: Color(0xFF172536),
    light: Color(0xFFE9E2CC),
    isSun: false,
    starCount: 22,
    mist: true,
  ),
  SkyPhase.night: _Palette(
    sky: [Color(0xFF0B1424), Color(0xFF17243B), Color(0xFF2A3A57)],
    far: Color(0xFF2D3B55),
    mid: Color(0xFF486474),
    shade: Color(0xFF2E4554),
    snow: Color(0xFFD5DEE4),
    near: Color(0xFF172636),
    trees: Color(0xFF0F1B28),
    light: Color(0xFFE9E2CC),
    isSun: false,
    starCount: 46,
    mist: false,
  ),
};

/// The landscape: the sky for [phase], its sun or moon, stars at dusk
/// and night, and three ranges of mountains made up from [seed], which
/// fade into the page below. Decoration only, so screen readers skip it.
class SkyHeader extends StatelessWidget {
  /// Creates the landscape.
  const SkyHeader({
    super.key,
    required this.phase,
    required this.height,
    required this.clearTop,
    required this.seed,
  });

  /// Which sky to draw.
  final SkyPhase phase;

  /// How tall it is.
  final double height;

  /// How much of the top is kept as open sky, for the status bar and the
  /// greeting: the mountains rise only below it.
  final double clearTop;

  /// The seed for the made-up mountains: the same seed always gives the
  /// same landscape. Home uses the date, so it changes once a day.
  final int seed;

  /// A seed for [day]: different for every date.
  static int seedFor(DateTime day) =>
      day.year * 10000 + day.month * 100 + day.day;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SkyPainter(
            palette: _palettes[phase]!,
            phase: phase,
            background: Theme.of(context).scaffoldBackgroundColor,
            clearTop: clearTop,
            seed: seed,
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.palette,
    required this.phase,
    required this.background,
    required this.clearTop,
    required this.seed,
  });

  final _Palette palette;
  final SkyPhase phase;
  final Color background;
  final double clearTop;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final random = Random(seed);
    // Peaks near the edges reach past them; keep everything inside.
    canvas.clipRect(rect);
    // The land: everything below the clear top.
    final land = h - clearTop;
    double y(double fraction) => clearTop + land * fraction;

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

    // The sun or moon, somewhere over the right half.
    final lightCentre = Offset(
      w * (0.55 + random.nextDouble() * 0.3),
      y(palette.isSun ? 0.30 : 0.18),
    );
    final radius = land * 0.20;
    _stars(canvas, size, Random(seed + 1), lightCentre, radius * 1.8);
    if (phase == SkyPhase.night && random.nextInt(3) == 0) {
      _shootingStar(canvas, size, Random(seed + 2));
    }
    _sunOrMoon(canvas, lightCentre, radius);
    if (phase == SkyPhase.day || phase == SkyPhase.dawn) {
      _birds(canvas, size, Random(seed + 3), y(0.05));
    }

    // The far range: low and soft, hazy with distance.
    final far = _ridge(random, w, y(0.40), land * 0.25, 0.5, count: 33);
    _fillBelow(canvas, far, h, palette.far);

    // The mountains: a row of smaller peaks behind, fainter with distance,
    // then a row of tall ones in front. Each peak has a lit face, a shaded
    // face and snow, like the app's icon; how many there are, where they
    // stand and how tall they are changes with the seed.
    _peakRow(
      canvas,
      random,
      width: w,
      base: y(0.95),
      minHeight: land * 0.35,
      maxHeight: land * 0.55,
      count: 4 + random.nextInt(3),
      distance: 0.45,
    );
    _peakRow(
      canvas,
      random,
      width: w,
      base: y(1.0),
      minHeight: land * 0.60,
      maxHeight: land * 0.95,
      count: 2 + random.nextInt(3),
      distance: 0,
    );
    if (palette.mist) {
      _mist(canvas, w, y(0.55), land * 0.25);
    }

    // The near ridge: rolling, with pines along its top.
    final near = _ridge(random, w, y(0.86), land * 0.16, 0.4, count: 33);
    _fillBelow(canvas, near, h, palette.near);
    _trees(canvas, near, Random(seed + 4), land);

    // Fade into the page, so the cards below start on plain ground.
    final fade = Rect.fromLTRB(0, y(0.62), w, h);
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

  /// A ridge line across the width: [count] points, made by "midpoint
  /// displacement". Start with a line at [base]; then, again and again,
  /// move the point halfway between two others up or down by a random
  /// amount that shrinks each round by [roughness] (closer to 1 gives
  /// more jagged ridges). [height] is how far peaks can rise above base.
  static List<Offset> _ridge(
    Random random,
    double width,
    double base,
    double height,
    double roughness, {
    int count = 65,
  }) {
    final heights = List<double>.filled(count, 0);
    heights[0] = random.nextDouble();
    heights[count - 1] = random.nextDouble();
    var step = count - 1;
    var spread = 1.0;
    while (step > 1) {
      final half = step ~/ 2;
      for (var start = 0; start + step < count; start += step) {
        final middle = (heights[start] + heights[start + step]) / 2;
        heights[start + half] = middle + (random.nextDouble() * 2 - 1) * spread;
      }
      spread *= roughness;
      step = half;
    }
    // Scale so the lowest point sits at the base and the highest at
    // [height] above it.
    final low = heights.reduce(min);
    final high = heights.reduce(max);
    final range = high - low == 0 ? 1 : high - low;
    return [
      for (var index = 0; index < count; index++)
        Offset(
          width * index / (count - 1),
          base - height * (heights[index] - low) / range,
        ),
    ];
  }

  /// The shape under [ridge], down to [bottom].
  static Path _pathBelow(List<Offset> ridge, double bottom) {
    return Path()..addPolygon([
      ...ridge,
      Offset(ridge.last.dx, bottom),
      Offset(ridge.first.dx, bottom),
    ], true);
  }

  void _fillBelow(
    Canvas canvas,
    List<Offset> ridge,
    double bottom,
    Color color,
  ) {
    canvas.drawPath(_pathBelow(ridge, bottom), Paint()..color = color);
  }

  /// A row of [count] peaks across [width], standing on [base], each
  /// between [minHeight] and [maxHeight] tall, spread out with some
  /// jitter. With [distance] above 0, the colours fade toward the far
  /// range, so the row looks further away. The tallest are drawn first,
  /// so smaller peaks stand in front of them.
  void _peakRow(
    Canvas canvas,
    Random random, {
    required double width,
    required double base,
    required double minHeight,
    required double maxHeight,
    required int count,
    required double distance,
  }) {
    Color faded(Color color) => Color.lerp(color, palette.far, distance)!;
    final peaks = [
      for (var index = 0; index < count; index++)
        (
          x: width * (index + 0.5 + (random.nextDouble() - 0.5) * 0.7) / count,
          height: minHeight + random.nextDouble() * (maxHeight - minHeight),
          // Each slope has its own steepness, so peaks lean.
          left: 0.9 + random.nextDouble() * 0.9,
          right: 0.9 + random.nextDouble() * 0.9,
        ),
    ]..sort((first, second) => second.height.compareTo(first.height));
    for (final peak in peaks) {
      _peak(
        canvas,
        top: Offset(peak.x, base - peak.height),
        left: peak.x - peak.height * peak.left,
        right: peak.x + peak.height * peak.right,
        base: base,
        lit: faded(palette.mid),
        shade: faded(palette.shade),
        snow: faded(palette.snow),
        snowDepth: peak.height * (0.18 + random.nextDouble() * 0.12),
      );
    }
  }

  /// One peak from [left] to [right] with its summit at [top]: the left
  /// face lit, the right face shaded, and a snow cap with a ragged lower
  /// edge, a little grey on the shaded side.
  void _peak(
    Canvas canvas, {
    required Offset top,
    required double left,
    required double right,
    required double base,
    required Color lit,
    required Color shade,
    required Color snow,
    required double snowDepth,
  }) {
    _fill(canvas, lit, [top, Offset(top.dx, base), Offset(left, base)]);
    _fill(canvas, shade, [top, Offset(right, base), Offset(top.dx, base)]);
    // Where the snowline meets each slope.
    final leftEdge = top.dx - (top.dx - left) * snowDepth / (base - top.dy);
    final rightEdge = top.dx + (right - top.dx) * snowDepth / (base - top.dy);
    final line = top.dy + snowDepth;
    final cap = [
      top,
      Offset(rightEdge, line),
      Offset(top.dx + (rightEdge - top.dx) * 0.5, line - snowDepth * 0.25),
      Offset(top.dx, line + snowDepth * 0.05),
      Offset(top.dx - (top.dx - leftEdge) * 0.45, line - snowDepth * 0.3),
      Offset(leftEdge, line),
    ];
    _fill(canvas, snow, cap);
    // The cap's shaded half, a little grey.
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(top.dx, 0, right, base));
    _fill(canvas, shade.withValues(alpha: 0.35), cap);
    canvas.restore();
  }

  void _fill(Canvas canvas, Color color, List<Offset> points) {
    canvas.drawPath(Path()..addPolygon(points, true), Paint()..color = color);
  }

  /// A soft band of mist lying in the valleys.
  void _mist(Canvas canvas, double width, double top, double depth) {
    final band = Rect.fromLTWH(0, top, width, depth);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(band),
    );
  }

  /// Pines along the near ridge: narrow triangles of varied height, in
  /// small clumps with gaps between.
  void _trees(Canvas canvas, List<Offset> ridge, Random random, double land) {
    final paint = Paint()..color = palette.trees;
    final width = ridge.last.dx;
    var x = random.nextDouble() * 12;
    while (x < width) {
      // The ridge's height at x.
      final position = x / width * (ridge.length - 1);
      final index = position.floor().clamp(0, ridge.length - 2);
      final t = position - index;
      final ground = ridge[index].dy * (1 - t) + ridge[index + 1].dy * t;
      final tall = land * (0.06 + random.nextDouble() * 0.07);
      final half = tall * 0.28;
      canvas.drawPath(
        Path()..addPolygon([
          Offset(x, ground - tall),
          Offset(x + half, ground + 1),
          Offset(x - half, ground + 1),
        ], true),
        paint,
      );
      // Mostly close together, now and then a clearing.
      x += random.nextDouble() < 0.15
          ? 20 + random.nextDouble() * 40
          : 3 + random.nextDouble() * 6;
    }
  }

  /// Scattered stars of different sizes and brightness in the upper sky,
  /// none behind the moon.
  void _stars(
    Canvas canvas,
    Size size,
    Random random,
    Offset avoid,
    double avoidRadius,
  ) {
    var drawn = 0;
    var tries = 0;
    while (drawn < palette.starCount && tries < palette.starCount * 10) {
      tries++;
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * (clearTop + (size.height - clearTop) * 0.4),
      );
      if ((point - avoid).distance < avoidRadius) {
        continue;
      }
      drawn++;
      // Most stars are faint and small; a few are bright.
      final radius = 0.35 + pow(random.nextDouble(), 3) * 1.3;
      final brightness = 0.25 + random.nextDouble() * 0.65;
      final color = const Color(0xFFF4F1E8).withValues(alpha: brightness);
      canvas.drawCircle(point, radius, Paint()..color = color);
      if (radius > 1.1) {
        canvas.drawCircle(
          point,
          radius * 3.2,
          Paint()..color = color.withValues(alpha: brightness * 0.12),
        );
      }
    }
  }

  /// A shooting star: a short bright streak that fades along its tail.
  void _shootingStar(Canvas canvas, Size size, Random random) {
    final start = Offset(
      size.width * (0.1 + random.nextDouble() * 0.5),
      clearTop * (0.3 + random.nextDouble() * 0.5),
    );
    final end = start + Offset(-46 - random.nextDouble() * 20, 18);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.9),
            const Color(0xFFFFFFFF).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromPoints(start, end)),
    );
  }

  /// A few birds far off: small, shallow "v" strokes.
  void _birds(Canvas canvas, Size size, Random random, double top) {
    final paint = Paint()
      ..color = const Color(0xFF2B3A48).withValues(alpha: 0.55)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final centre = Offset(
      size.width * (0.15 + random.nextDouble() * 0.3),
      top + random.nextDouble() * 10,
    );
    final count = 2 + random.nextInt(3);
    for (var bird = 0; bird < count; bird++) {
      final at =
          centre + Offset(bird * 11.0, (bird.isEven ? 0 : 5) + bird * 2.0);
      final span = 3.5 + random.nextDouble() * 1.5;
      canvas.drawPath(
        Path()
          ..moveTo(at.dx - span, at.dy - span * 0.5)
          ..quadraticBezierTo(
            at.dx - span * 0.4,
            at.dy - span * 0.6,
            at.dx,
            at.dy,
          )
          ..quadraticBezierTo(
            at.dx + span * 0.4,
            at.dy - span * 0.6,
            at.dx + span,
            at.dy - span * 0.5,
          ),
        paint,
      );
    }
  }

  /// The sun (a soft glow) or the moon (a glow, a shade for roundness and
  /// faint craters for texture).
  void _sunOrMoon(Canvas canvas, Offset centre, double radius) {
    final light = palette.light;
    canvas
      ..drawCircle(
        centre,
        radius * 2.0,
        Paint()..color = light.withValues(alpha: 0.07),
      )
      ..drawCircle(
        centre,
        radius * 1.45,
        Paint()..color = light.withValues(alpha: 0.12),
      )
      ..drawCircle(centre, radius, Paint()..color = light);
    if (palette.isSun) {
      return;
    }
    canvas.drawCircle(
      centre + Offset(radius * 0.25, radius * 0.2),
      radius * 0.94,
      Paint()..color = const Color(0xFFB9B29C).withValues(alpha: 0.2),
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

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.phase != phase ||
      old.background != background ||
      old.clearTop != clearTop ||
      old.seed != seed;
}
