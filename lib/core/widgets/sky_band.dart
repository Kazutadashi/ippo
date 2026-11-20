// SPDX-License-Identifier: GPL-3.0-or-later

/// The top bar of the Habits, Food, Exercise and Sleep tabs, on the
/// Home landscape, cut off.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../dates.dart';
import 'sky_header.dart';

/// How much taller than a plain top bar the band is: room for the tops
/// of the mountains, and for the fade into the page.
const double _extraHeight = 36;

/// A tab's top bar on the same picture as the top of Home (the same sky,
/// moon or sun, stars and mountains, made the same way for the day), cut
/// off below the title and fading into the page. The title and buttons
/// are white on it, whatever the theme.
///
/// It is a plain [AppBar] otherwise, with the same [title] and
/// [actions].
class SkyAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates the bar.
  const SkyAppBar({super.key, required this.title, this.actions, this.phase});

  /// The tab's name.
  final Widget title;

  /// Buttons on the right, such as the day picker.
  final List<Widget>? actions;

  /// The sky to draw, or null for the sky at this hour (always, in the
  /// app; tests set it to look at each sky).
  final SkyPhase? phase;

  @override
  Size get preferredSize => const Size.fromHeight(52 + _extraHeight);

  @override
  Widget build(BuildContext context) {
    final page = Theme.of(context).colorScheme.surface;
    final topInset = MediaQuery.paddingOf(context).top;
    final now = DateTime.now();
    return AppBar(
      title: title,
      actions: actions,
      // White on the sky; white icons in the phone's status bar too.
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      // Room below the buttons for the mountains and the fade.
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(_extraHeight),
        child: SizedBox.shrink(),
      ),
      flexibleSpace: ExcludeSemantics(
        child: ClipRect(
          child: Stack(
            children: [
              // The whole Home picture, at Home's size and place; the
              // bar shows only its top.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SkyHeader(
                  phase: phase ?? SkyPhase.of(now),
                  height: topInset + 156,
                  clearTop: topInset + 44,
                  seed: SkyHeader.seedFor(currentDay(now)),
                ),
              ),
              // Fading into the page, so the cut is never a hard edge.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [page.withValues(alpha: 0), page],
                      stops: const [0.7, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
