// SPDX-License-Identifier: GPL-3.0-or-later

/// The top bar of the Habits, Food, Exercise and Sleep tabs, drawn as a
/// slim band of the same sky as the Home landscape.
library;

import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../dates.dart';
import 'sky_header.dart';

/// How tall the ridge along the band's bottom edge is.
const double _ridgeHeight = 16;

/// A tab's top bar on a band of sky: the colours of the sky at this
/// hour, a few stars at dusk and night, faint mountains far off, and a
/// ridge in the page's colour along the bottom, so the band flows into
/// the page as the Home landscape does. The title and buttons are white
/// on it, whatever the theme.
///
/// It is a plain [AppBar] otherwise, with the same [title] and
/// [actions].
class SkyAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates the bar.
  const SkyAppBar({super.key, required this.title, this.actions});

  /// The tab's name.
  final Widget title;

  /// Buttons on the right, such as the day picker.
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(52 + _ridgeHeight);

  @override
  Widget build(BuildContext context) {
    final page = Theme.of(context).colorScheme.surface;
    final now = DateTime.now();
    return AppBar(
      title: title,
      actions: actions,
      // White on the sky; white icons in the phone's status bar too.
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      // Room below the buttons for the ridge, so nothing sits on it.
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(_ridgeHeight),
        child: SizedBox.shrink(),
      ),
      flexibleSpace: ExcludeSemantics(
        child: CustomPaint(
          painter: _BandPainter(
            phase: SkyPhase.of(now),
            page: page,
            // The same mountains all day, new ones each day, as on Home.
            seed: SkyHeader.seedFor(currentDay(now)),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _BandPainter extends CustomPainter {
  _BandPainter({required this.phase, required this.page, required this.seed});

  final SkyPhase phase;
  final Color page;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final sky = skyColorsFor(phase);
    canvas.clipRect(rect);

    // The upper part of the sky only: the band is a sliver of it.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sky[0], sky[1]],
        ).createShader(rect),
    );

    final random = Random(seed + 21);
    if (hasStarsAt(phase)) {
      final star = Paint()..color = const Color(0xFFF2EEE2);
      for (var index = 0; index < 18; index++) {
        star.color = const Color(0xFFF2EEE2)
            .withValues(alpha: 0.25 + random.nextDouble() * 0.5);
        canvas.drawCircle(
          Offset(random.nextDouble() * w, random.nextDouble() * h * 0.7),
          0.5 + random.nextDouble() * 0.8,
          star,
        );
      }
    }

    // Faint mountains far off, in the rock colour faded into the sky.
    final far = mountainRidge(random, w, h - 2, h * 0.5);
    canvas.drawPath(
      _below(far, h),
      Paint()..color = Color.lerp(rockColorFor(phase), sky[1], 0.55)!,
    );

    // A low ridge in the page's own colour along the bottom: the page
    // rises into the band like land into the sky.
    final near = mountainRidge(random, w, h + 1, _ridgeHeight);
    canvas.drawPath(_below(near, h + 1), Paint()..color = page);
  }

  /// The area under [ridge], down to [bottom].
  static Path _below(List<Offset> ridge, double bottom) {
    return Path()..addPolygon([
      ...ridge,
      Offset(ridge.last.dx, bottom),
      Offset(ridge.first.dx, bottom),
    ], true);
  }

  @override
  bool shouldRepaint(_BandPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.page != page ||
      oldDelegate.seed != seed;
}
