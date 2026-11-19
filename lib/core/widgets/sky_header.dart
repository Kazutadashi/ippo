// SPDX-License-Identifier: GPL-3.0-or-later

/// The landscape at the top of the home screen: a great snowy mountain
/// range seen across open country, under a sky that follows the time of
/// day.
///
/// The land is made up fresh for each day (the date is the seed of a
/// random number generator), so Home looks a little different every day,
/// and the same all through one day.
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

/// The colours of one sky and its land.
class _Palette {
  const _Palette({
    required this.sky,
    required this.snow,
    required this.shadow,
    required this.rock,
    required this.haze,
    required this.hills,
    required this.nearHills,
    required this.forest,
    required this.light,
    required this.isSun,
    required this.starCount,
    required this.mist,
  });

  /// The sky from top to horizon.
  final List<Color> sky;

  /// The snow on the range, in the light.
  final Color snow;

  /// The snow in shadow: the gullies and faces turned from the light.
  final Color shadow;

  /// Bare rock: ribs between the snow, and the range's lower slopes.
  final Color rock;

  /// The haze at the foot of the range, far away.
  final Color haze;

  /// The rounded foothills in front of the range.
  final Color hills;

  /// The nearer foothills, a little darker.
  final Color nearHills;

  /// The spruce forest and the tall trees in front.
  final Color forest;

  /// The sun or moon.
  final Color light;

  /// Whether [light] is the sun (else the moon, with craters).
  final bool isSun;

  /// How many stars show.
  final int starCount;

  /// Whether low mist lies over the land.
  final bool mist;
}

const Map<SkyPhase, _Palette> _palettes = {
  SkyPhase.dawn: _Palette(
    sky: [Color(0xFF4A6A96), Color(0xFF9AB2D0), Color(0xFFF2C6A0)],
    snow: Color(0xFFF8E9DC),
    shadow: Color(0xFFA8A4C2),
    rock: Color(0xFF6E6876),
    haze: Color(0xFFD9C4C0),
    hills: Color(0xFF7A5C50),
    nearHills: Color(0xFF5E463E),
    forest: Color(0xFF243630),
    light: Color(0xFFFFD9A0),
    isSun: true,
    starCount: 0,
    mist: true,
  ),
  SkyPhase.day: _Palette(
    sky: [Color(0xFF2F6BB0), Color(0xFF6FA3DA), Color(0xFFBFD8EE)],
    snow: Color(0xFFF5F8FB),
    shadow: Color(0xFFA3B6CC),
    rock: Color(0xFF66717F),
    haze: Color(0xFFC9D8E6),
    hills: Color(0xFF7B6050),
    nearHills: Color(0xFF5F4A3E),
    forest: Color(0xFF1F3A2E),
    light: Color(0xFFFFF4D6),
    isSun: true,
    starCount: 0,
    mist: false,
  ),
  SkyPhase.dusk: _Palette(
    sky: [Color(0xFF16213A), Color(0xFF34406A), Color(0xFF9A7488)],
    snow: Color(0xFFDCD3DE),
    shadow: Color(0xFF7E7B9C),
    rock: Color(0xFF4C4E66),
    haze: Color(0xFF7E6F86),
    hills: Color(0xFF453A48),
    nearHills: Color(0xFF332B38),
    forest: Color(0xFF18222C),
    light: Color(0xFFE9E2CC),
    isSun: false,
    starCount: 22,
    mist: true,
  ),
  SkyPhase.night: _Palette(
    sky: [Color(0xFF0B1424), Color(0xFF17243B), Color(0xFF2A3A57)],
    snow: Color(0xFFB4C0CF),
    shadow: Color(0xFF5F6D86),
    rock: Color(0xFF384459),
    haze: Color(0xFF34435C),
    hills: Color(0xFF242E3D),
    nearHills: Color(0xFF1B2330),
    forest: Color(0xFF101922),
    light: Color(0xFFE9E2CC),
    isSun: false,
    starCount: 46,
    mist: false,
  ),
};

/// The landscape: the sky for [phase], its sun or moon, stars at dusk
/// and night, and a mountain range across open country made up from
/// [seed], fading into the page below. Decoration only, so screen
/// readers skip it.
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

  /// The seed for the made-up land: the same seed always gives the same
  /// landscape. Home uses the date, so it changes once a day.
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
    // Keep everything inside, also trees and peaks near the edges.
    canvas.clipRect(rect);
    // The land: everything below the clear top. Heights in it go from
    // 0 (its top) to 1 (the bottom).
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

    // The sun or moon, above the range, right of the greeting and left
    // of the gear, so it never sits behind either.
    final lightCentre = Offset(
      w * (0.58 + random.nextDouble() * 0.2),
      y(palette.isSun ? 0.12 : 0.08),
    );
    final radius = land * 0.13;
    _stars(canvas, size, Random(seed + 1), lightCentre, radius * 1.8);
    if (phase == SkyPhase.night && random.nextInt(3) == 0) {
      _shootingStar(canvas, size, Random(seed + 2));
    }
    _sunOrMoon(canvas, lightCentre, radius);
    if (phase == SkyPhase.day || phase == SkyPhase.dawn) {
      _birds(canvas, size, Random(seed + 3), clearTop * 0.8);
    }

    // The range: tall, jagged and continuous across the whole view.
    _range(canvas, random, w, y, land);

    // Rounded foothills in front of its foot, two layers.
    _hills(canvas, random, w, h, y(0.66), land * 0.20, palette.hills);
    if (palette.mist) {
      _mist(canvas, w, y(0.58), land * 0.25);
    }
    _hills(canvas, random, w, h, y(0.76), land * 0.16, palette.nearHills);

    // A long, dense line of spruce forest on the flats.
    _forestLine(canvas, Random(seed + 5), w, h, y(0.84), land);

    // A few tall spruces close by, rising high into the view.
    _nearTrees(canvas, Random(seed + 6), w, h, land);

    // Fade into the page, so the cards below start on plain ground.
    final fade = Rect.fromLTRB(0, y(0.74), w, h);
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

  /// The great range: a jagged ridge with many summits across the whole
  /// width, mostly snow. Faces turned from the light are cut by shadowed
  /// gullies, dark ribs of rock run down from the ridge, the lower slopes
  /// turn to rock, and haze lies at its foot.
  void _range(
    Canvas canvas,
    Random random,
    double w,
    double Function(double) y,
    double land,
  ) {
    final ridge = _rangeRidge(random, w, y(0.62), land * 0.66);
    final foot = y(0.80);
    final shape = _pathBelow(ridge, foot);
    canvas.drawPath(shape, Paint()..color = palette.snow);

    canvas
      ..save()
      ..clipPath(shape);
    // Shadowed faces: from each stretch of ridge that falls to the right,
    // a slanting gully runs down and to the left.
    final shadow = Paint()..color = palette.shadow;
    for (var index = 0; index + 1 < ridge.length; index++) {
      final from = ridge[index];
      final to = ridge[index + 1];
      if (to.dy <= from.dy) {
        continue;
      }
      final depth = land * (0.18 + random.nextDouble() * 0.30);
      final run = to.dx - from.dx;
      canvas.drawPath(
        Path()..addPolygon([
          from,
          to,
          Offset(to.dx - run * 0.6, to.dy + depth * 0.8),
          Offset(from.dx - run * 0.3, from.dy + depth),
        ], true),
        shadow,
      );
    }
    // Ribs of bare rock running down from the ridge.
    final rib = Paint()..strokeCap = StrokeCap.round;
    for (var count = 0; count < 18; count++) {
      final start = ridge[random.nextInt(ridge.length)];
      final length = land * (0.08 + random.nextDouble() * 0.25);
      rib
        ..strokeWidth = 0.7 + random.nextDouble() * 1.3
        ..color = palette.rock.withValues(
          alpha: 0.35 + random.nextDouble() * 0.4,
        );
      canvas.drawLine(
        start + Offset(0, land * 0.03),
        start + Offset((random.nextDouble() - 0.5) * 8, length),
        rib,
      );
    }
    // The lower slopes: bare rock, then haze at the foot.
    final lower = Rect.fromLTRB(0, y(0.25), w, foot);
    canvas
      ..drawRect(
        lower,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.rock.withValues(alpha: 0),
              palette.rock.withValues(alpha: 0.55),
              palette.haze.withValues(alpha: 0.85),
            ],
            stops: const [0, 0.6, 1],
          ).createShader(lower),
      )
      ..restore();
  }

  /// A line of rounded hills along [base], rising up to [height], filled
  /// down to [bottom]: a gentle ridge drawn with curves, not corners.
  void _hills(
    Canvas canvas,
    Random random,
    double w,
    double bottom,
    double base,
    double height,
    Color color,
  ) {
    final points = _ridge(random, w, base, height, 0.45, count: 9);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final point = points[index];
      final middle = Offset(
        (previous.dx + point.dx) / 2,
        (previous.dy + point.dy) / 2,
      );
      path.quadraticBezierTo(previous.dx, previous.dy, middle.dx, middle.dy);
    }
    path
      ..lineTo(points.last.dx, points.last.dy)
      ..lineTo(w, bottom)
      ..lineTo(0, bottom)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  /// A long, dense line of small spruces along [line]: the far edge of
  /// a forest, filled in below.
  void _forestLine(
    Canvas canvas,
    Random random,
    double w,
    double bottom,
    double line,
    double land,
  ) {
    final paint = Paint()..color = palette.forest;
    canvas.drawRect(Rect.fromLTRB(0, line, w, bottom), paint);
    var x = 0.0;
    while (x < w) {
      final tall = land * (0.04 + random.nextDouble() * 0.06);
      final ground = line + random.nextDouble() * 2;
      _spruce(canvas, paint, Offset(x, ground), tall, random);
      x += 2 + random.nextDouble() * 3;
    }
  }

  /// A few tall spruces close by, spread across the view, some of them
  /// in small groups.
  void _nearTrees(
    Canvas canvas,
    Random random,
    double w,
    double bottom,
    double land,
  ) {
    final paint = Paint()..color = palette.forest;
    final count = 4 + random.nextInt(4);
    for (var tree = 0; tree < count; tree++) {
      final x = w * (tree + random.nextDouble()) / count;
      final tall = land * (0.35 + random.nextDouble() * 0.40);
      _spruce(canvas, paint, Offset(x, bottom), tall, random);
      // Now and then a smaller one beside it.
      if (random.nextDouble() < 0.4) {
        _spruce(
          canvas,
          paint,
          Offset(x + 6 + random.nextDouble() * 6, bottom),
          tall * (0.5 + random.nextDouble() * 0.3),
          random,
        );
      }
    }
  }

  /// One spruce standing at [foot], [tall] high: a narrow spire with
  /// layered, slightly ragged branches, widest near the ground.
  void _spruce(
    Canvas canvas,
    Paint paint,
    Offset foot,
    double tall,
    Random random,
  ) {
    const layers = 7;
    final widest = tall * 0.17;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var layer = 1; layer <= layers; layer++) {
      final t = layer / layers;
      final at = foot.dy - tall + tall * t;
      final reach = widest * t * (0.8 + random.nextDouble() * 0.4);
      // Each layer of branches sticks out, then tucks back in.
      left
        ..add(Offset(foot.dx - reach, at))
        ..add(Offset(foot.dx - reach * 0.45, at - tall * 0.02));
      right
        ..add(Offset(foot.dx + reach, at))
        ..add(Offset(foot.dx + reach * 0.45, at - tall * 0.02));
    }
    canvas.drawPath(
      Path()..addPolygon([
        Offset(foot.dx, foot.dy - tall),
        ...right,
        Offset(foot.dx + 1, foot.dy),
        Offset(foot.dx - 1, foot.dy),
        ...left.reversed,
      ], true),
      paint,
    );
  }

  /// A ridge line across the width: [count] points, made by "midpoint
  /// displacement". Start with a line at [base]; then, again and again,
  /// move the point halfway between two others up or down by a random
  /// amount that shrinks each round by [roughness] (closer to 1 gives
  /// more jagged ridges). [height] is how far it can rise above base.
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

  /// The ridge of a great range: two or three broad massifs, which give
  /// it its overall shape, with smaller summits and notches along them
  /// (a jagged [_ridge] on top). Rises up to [height] above [base].
  static List<Offset> _rangeRidge(
    Random random,
    double width,
    double base,
    double height,
  ) {
    const count = 49;
    final detail = _ridge(random, width, 0, 1, 0.55, count: count);
    final massifs = [
      for (var index = 0; index < 2 + random.nextInt(3); index++)
        (
          centre: random.nextDouble(),
          spread: 0.12 + random.nextDouble() * 0.18,
          size: 0.6 + random.nextDouble() * 0.4,
        ),
    ];
    final heights = <double>[];
    for (var index = 0; index < count; index++) {
      final x = index / (count - 1);
      // The massifs: smooth bumps, the tallest one wins. Between them the
      // range never drops below a third, so it runs on unbroken.
      var shape = 0.35;
      for (final massif in massifs) {
        final distance = (x - massif.centre) / massif.spread;
        shape = max(shape, massif.size * exp(-distance * distance));
      }
      // The detail, from 0 (lowest) to 1 (highest), adds the summits.
      final jag = -detail[index].dy;
      heights.add(shape * 0.75 + jag * 0.25 * (0.4 + shape));
    }
    final high = heights.reduce(max);
    return [
      for (var index = 0; index < count; index++)
        Offset(
          width * index / (count - 1),
          base - height * heights[index] / high,
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

  /// A soft band of mist lying over the land.
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
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(band),
    );
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
        random.nextDouble() * (clearTop + (size.height - clearTop) * 0.3),
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
