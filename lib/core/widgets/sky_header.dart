// SPDX-License-Identifier: GPL-3.0-or-later

/// The landscape at the top of the home screen: a great snowy mountain
/// range seen from a wooded hilltop, across a valley, under a sky that
/// follows the time of day.
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
    this.skyOnly = false,
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

  /// Only the sky, with its birds by day or its stars and shooting star
  /// by night: no sun or moon, and no land. The tabs' top bars use this
  /// (`sky_band.dart`), so only Home has the full landscape.
  final bool skyOnly;

  /// A seed for [day]: different for every date.
  static int seedFor(DateTime day) =>
      day.year * 10000 + day.month * 100 + day.day;

  @override
  Widget build(BuildContext context) {
    // A whole number of screen pixels tall: a last row only partly
    // covered would show a thin line of the layers under the fade.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final wholeHeight = (height * pixelRatio).round() / pixelRatio;
    return ExcludeSemantics(
      child: SizedBox(
        height: wholeHeight,
        width: double.infinity,
        child: CustomPaint(
          painter: _SkyPainter(
            palette: _palettes[phase]!,
            phase: phase,
            background: Theme.of(context).scaffoldBackgroundColor,
            clearTop: clearTop,
            seed: seed,
            skyOnly: skyOnly,
          ),
        ),
      ),
    );
  }
}

/// How far above [SkyHeader.clearTop] the Home greeting starts (Home
/// puts it 2 below the status bar, and the land 44 below it).
const double _greetingTop = 42;

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.palette,
    required this.phase,
    required this.background,
    required this.clearTop,
    required this.seed,
    required this.skyOnly,
  });

  final _Palette palette;
  final SkyPhase phase;
  final Color background;
  final double clearTop;
  final int seed;
  final bool skyOnly;

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
      y(palette.isSun ? 0.02 : -0.06),
    );
    final radius = land * 0.13;
    _stars(canvas, size, Random(seed + 1), lightCentre, radius * 1.8);
    // A shooting star every night and every dusk.
    if (phase == SkyPhase.night || phase == SkyPhase.dusk) {
      _shootingStar(canvas, size, Random(seed + 2));
    }
    if (phase == SkyPhase.night) {
      // Once, only one night in three had a shooting star, and choosing
      // that used up a random number. It is still drawn and thrown away,
      // so the mountains made from the numbers after it keep their shape.
      random.nextInt(3);
    }
    if (!skyOnly) {
      _sunOrMoon(canvas, lightCentre, radius);
    }
    if (phase == SkyPhase.day || phase == SkyPhase.dawn) {
      _birds(canvas, size, Random(seed + 3), clearTop * 0.8);
    }
    if (skyOnly) {
      return;
    }

    // A farther range behind, drawn like the near one but faded toward
    // the sky, as distance does, and a little lower, so it shows in the
    // gaps between the near summits instead of standing above them.
    // Its own random numbers, so the near range keeps its shape.
    _range(
      canvas,
      Random(seed + 7),
      w,
      y,
      land,
      lightCentre.dx,
      ridgeBase: y(0.60),
      ridgeHeight: land * 0.46,
      foot: y(0.80),
      distance: 0.45,
    );

    // The range: tall, jagged and continuous across the whole view, its
    // foot running down into the valley, behind the foothills.
    _range(
      canvas,
      random,
      w,
      y,
      land,
      lightCentre.dx,
      ridgeBase: y(0.66),
      ridgeHeight: land * 0.56,
      foot: y(0.88),
      distance: 0,
    );
    if (palette.mist) {
      _mist(canvas, w, y(0.62), land * 0.25);
    }

    // We look out from the top of a hill: the land drops away in front
    // of us into a wooded valley, then rises again in forested foothills
    // to the foot of the mountains. Drawn from far to near.
    final forestRandom = Random(seed + 5);
    _woodedHills(
      canvas,
      forestRandom,
      w,
      h,
      base: y(0.76),
      height: land * 0.15,
      land: land,
      color: Color.lerp(palette.forest, palette.haze, 0.5)!,
    );
    _woodedHills(
      canvas,
      forestRandom,
      w,
      h,
      base: y(0.80),
      height: land * 0.03,
      land: land,
      color: Color.lerp(palette.forest, palette.haze, 0.25)!,
    );

    // The hill we stand on, and a few tall spruces on it close by,
    // rising high into the view.
    final hill = _hillWeStandOn(Random(seed + 8), w, h, y);
    canvas.drawPath(hill.shape, Paint()..color = palette.forest);
    _nearTrees(canvas, Random(seed + 6), w, hill.groundAt, land);

    // Fade into the page, so the cards below start on plain ground.
    // It reaches the plain page colour a little before the bottom and
    // runs one pixel past it, so no sliver of dark ground shows at the
    // edge when the height falls between two screen pixels.
    final fade = Rect.fromLTRB(0, y(0.74), w, h + 1);
    canvas.drawRect(
      fade,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [background.withValues(alpha: 0), background],
          stops: const [0, 0.92],
        ).createShader(fade),
    );
  }

  /// A great range: a ridge across the whole width with a few clear
  /// summits. The mountains are bare rock, with snow only on the tops,
  /// above a ragged snowline, so the tallest peaks carry the most. Each
  /// mountain's face turned from the light is in shadow (darker rock,
  /// grey-blue snow), and haze lies at its foot. [lightX] is where the
  /// sun or moon is across the view.
  ///
  /// The ridge rises up to [ridgeHeight] above [ridgeBase], and the
  /// mountains reach down to [foot]. [distance], from 0 to 1, blends
  /// every colour toward the sky at the horizon: 0 for the near range,
  /// more for one farther away.
  void _range(
    Canvas canvas,
    Random random,
    double w,
    double Function(double) y,
    double land,
    double lightX, {
    required double ridgeBase,
    required double ridgeHeight,
    required double foot,
    required double distance,
  }) {
    final ridge = _rangeRidge(random, w, ridgeBase, ridgeHeight);
    final horizon = palette.sky.last;
    Color faded(Color color) => Color.lerp(color, horizon, distance)!;
    final shape = _pathBelow(ridge, foot);
    final faces = _shadedFaces(ridge, foot, land, lightX);
    canvas
      ..drawPath(shape, Paint()..color = faded(palette.rock))
      ..save()
      ..clipPath(shape);
    final darkRock = Paint()
      ..color = faded(Color.lerp(palette.rock, Colors.black, 0.3)!);
    for (final face in faces) {
      canvas.drawPath(face, darkRock);
    }

    // The snow: above a snowline a little below the highest summit, with
    // a ragged lower edge.
    final highest = ridge.map((point) => point.dy).reduce(min);
    final snowline = highest + (foot - highest) * 0.32;
    final snowArea = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0);
    for (var x = w; x >= 0; x -= 6) {
      snowArea.lineTo(x, snowline + (random.nextDouble() - 0.4) * land * 0.07);
    }
    snowArea.close();
    canvas
      ..save()
      ..clipPath(snowArea)
      ..drawPath(shape, Paint()..color = faded(palette.snow));
    final snowShadow = Paint()..color = faded(palette.shadow);
    for (final face in faces) {
      canvas.drawPath(face, snowShadow);
    }
    canvas.restore();

    // Haze at the foot, far away.
    final lower = Rect.fromLTRB(0, ridgeBase - land * 0.16, w, foot);
    canvas
      ..drawRect(
        lower,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.haze.withValues(alpha: 0),
              palette.haze.withValues(alpha: 0.8),
            ],
          ).createShader(lower),
      )
      ..restore();
  }

  /// The face of each mountain turned from the light, which is at
  /// [lightX]: a mountain left of the light is in shadow on its left
  /// slope, one right of it on its right slope. A face runs from the
  /// summit down that slope to the valley, with an edge that slants down
  /// from the summit, so the face widens toward the [foot]. Even a steep,
  /// narrow face gets some slant, or it would look like a stripe; a drop
  /// too small to read as a mountain gets no face. Only the shading
  /// depends on the light: the mountains stay the same.
  static List<Path> _shadedFaces(
    List<Offset> ridge,
    double foot,
    double land,
    double lightX,
  ) {
    final faces = <Path>[];
    for (final (summit, rightValley) in _faces(ridge)) {
      final peak = ridge[summit];
      final shadeLeft = peak.dx < lightX;
      // The valley on the shaded side, one point at a time down the
      // slope until it rises again.
      var valley = summit;
      if (shadeLeft) {
        while (valley > 0 && ridge[valley - 1].dy >= ridge[valley].dy) {
          valley--;
        }
      } else {
        valley = rightValley;
      }
      if (ridge[valley].dy - peak.dy < land * 0.06) {
        continue;
      }
      // Which way the face's slanted edge goes: right of the summit for
      // a right face, left of it for a left one.
      final direction = shadeLeft ? -1.0 : 1.0;
      final span = max((ridge[valley].dx - peak.dx).abs(), land * 0.6);
      // The slope from the summit down to that valley.
      final slope = shadeLeft
          ? [for (var index = summit; index >= valley; index--) ridge[index]]
          : [for (var index = summit; index <= valley; index++) ridge[index]];
      faces.add(
        Path()..addPolygon([
          ...slope,
          Offset(ridge[valley].dx + direction * span * 0.2, foot),
          Offset(peak.dx + direction * span * 0.6, foot),
        ], true),
      );
    }
    return faces;
  }

  /// Each summit of [ridge] (higher than both neighbours: a smaller y)
  /// with the valley that follows it, as point indexes.
  static List<(int, int)> _faces(List<Offset> ridge) {
    final faces = <(int, int)>[];
    var index = 1;
    while (index < ridge.length - 1) {
      final isSummit =
          ridge[index].dy <= ridge[index - 1].dy &&
          ridge[index].dy < ridge[index + 1].dy;
      if (!isSummit) {
        index++;
        continue;
      }
      var valley = index + 1;
      while (valley < ridge.length - 1 &&
          ridge[valley + 1].dy >= ridge[valley].dy) {
        valley++;
      }
      faces.add((index, valley));
      index = valley + 1;
    }
    return faces;
  }

  /// A line of rounded hills along [base], rising up to [height], with
  /// spruce forest on them: small trees all along the top of the hills,
  /// following their rise and fall, filled in below down to [bottom].
  void _woodedHills(
    Canvas canvas,
    Random random,
    double w,
    double bottom, {
    required double base,
    required double height,
    required double land,
    required Color color,
  }) {
    final paint = Paint()..color = color;
    final ground = _curveThrough(
      _ridge(random, w, base, height, 0.5, count: 9),
    );
    canvas.drawPath(_shapeBelow(ground, w, bottom), paint);
    var x = 0.0;
    while (x < w) {
      final tall = land * (0.03 + random.nextDouble() * 0.04);
      _spruce(canvas, paint, Offset(x, ground.heightAt(x) + 1), tall, random);
      x += 2 + random.nextDouble() * 3;
    }
  }

  /// The hill we look out from: a broad, rounded brow across the bottom
  /// of the view, highest a little off centre and falling away to both
  /// sides. The land beyond it is lower, so its top hides the near part
  /// of the valley. Returns its shape and, for any x, the height of its
  /// top there, so trees can stand on it.
  ({Path shape, double Function(double) groundAt}) _hillWeStandOn(
    Random random,
    double w,
    double bottom,
    double Function(double) y,
  ) {
    final crest = w * (0.3 + random.nextDouble() * 0.4);
    final top = y(0.80);
    final ground = _curveThrough([
      Offset(0, y(0.89)),
      Offset(crest * 0.5, y(0.82)),
      Offset(crest, top),
      Offset(crest + (w - crest) * 0.5, y(0.82)),
      Offset(w, y(0.89)),
    ]);
    return (shape: _shapeBelow(ground, w, bottom), groundAt: ground.heightAt);
  }

  /// A smooth line through [points] (sorted by x): straight lines between
  /// them, with the corners rounded off. Its [_Curve.heightAt] says how
  /// high the line is at any x.
  static _Curve _curveThrough(List<Offset> points) {
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
    path.lineTo(points.last.dx, points.last.dy);
    return _Curve(path, points);
  }

  /// The area under [curve], from the left edge to [w], down to [bottom].
  static Path _shapeBelow(_Curve curve, double w, double bottom) {
    return Path.from(curve.path)
      ..lineTo(w, bottom)
      ..lineTo(0, bottom)
      ..close();
  }

  /// A few tall spruces close by, spread across the view, some of them
  /// in small groups.
  void _nearTrees(
    Canvas canvas,
    Random random,
    double w,
    double Function(double) groundAt,
    double land,
  ) {
    final paint = Paint()..color = palette.forest;
    final count = 4 + random.nextInt(4);
    for (var tree = 0; tree < count; tree++) {
      final x = w * (tree + random.nextDouble()) / count;
      final tall = land * (0.35 + random.nextDouble() * 0.40);
      // A little below the top of the hill, so the foot never shows.
      _spruce(canvas, paint, Offset(x, groundAt(x) + 3), tall, random);
      // Now and then a smaller one beside it.
      if (random.nextDouble() < 0.4) {
        final beside = x + 6 + random.nextDouble() * 6;
        _spruce(
          canvas,
          paint,
          Offset(beside, groundAt(beside) + 3),
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

  /// The ridge of a great range: two to four broad massifs, which give
  /// it its overall shape, with a few smaller summits along them (a
  /// little of a jagged [_ridge] on top). Rises up to [height] above [base].
  static List<Offset> _rangeRidge(
    Random random,
    double width,
    double base,
    double height,
  ) {
    const count = 25;
    final detail = _ridge(random, width, 0, 1, 0.5, count: count);
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
      heights.add(shape * 0.85 + jag * 0.15 * (0.4 + shape));
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
  ///
  /// It is in the top left, just above the Home greeting (which starts
  /// [_greetingTop] above [clearTop]) and below the phone's status bar,
  /// so it never crosses the greeting. The tabs' sky band draws the same
  /// sky, so it is in the same place there.
  void _shootingStar(Canvas canvas, Size size, Random random) {
    final topOfText = clearTop - _greetingTop;
    final start = Offset(
      size.width * (0.3 + random.nextDouble() * 0.1),
      topOfText - 8 - random.nextDouble() * 4,
    );
    final end = start + Offset(-50 - random.nextDouble() * 16, 6);
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
      old.seed != seed ||
      old.skyOnly != skyOnly;
}

/// A smooth line across the view, such as the top of a hill, and the
/// points it was drawn through.
class _Curve {
  _Curve(this.path, this.points);

  /// The line itself, from the left edge to the right.
  final Path path;

  /// The points it rounds off, sorted by x.
  final List<Offset> points;

  /// How high the line is at [x]. The rounded line runs through the
  /// middle of each pair of points, bending toward the point itself; so
  /// following the straight lines between those middles is close enough
  /// to stand a tree on.
  double heightAt(double x) {
    final middles = [
      points.first,
      for (var index = 1; index < points.length; index++)
        Offset(
          (points[index - 1].dx + points[index].dx) / 2,
          (points[index - 1].dy + points[index].dy) / 2,
        ),
      points.last,
    ];
    for (var index = 1; index < middles.length; index++) {
      final right = middles[index];
      if (x <= right.dx) {
        final left = middles[index - 1];
        final span = right.dx - left.dx;
        final t = span == 0 ? 0.0 : (x - left.dx) / span;
        return left.dy + (right.dy - left.dy) * t;
      }
    }
    return points.last.dy;
  }
}
