// SPDX-License-Identifier: GPL-3.0-or-later

/// Asking before a form with changes is closed.
library;

import 'package:material_ui/material_ui.dart';

/// Wraps a form screen so that leaving it with unsaved changes asks
/// "Discard changes?" first. A form with no changes closes at once.
///
/// One stray back swipe should never lose a filled-in food label. The
/// form describes its contents with [snapshot]; the guard remembers the
/// first one and compares it when the user leaves. Saving closes the
/// form with `Navigator.pop`, which is never stopped.
///
/// The form's ✕ button must call `Navigator.maybePop`, so it goes
/// through this guard like the back button and back gesture do.
class DiscardGuard extends StatefulWidget {
  /// Creates the guard around [child].
  const DiscardGuard({super.key, required this.snapshot, required this.child});

  /// Describes everything the user can change on the form, as text.
  final String Function() snapshot;

  /// The form screen.
  final Widget child;

  @override
  State<DiscardGuard> createState() => _DiscardGuardState();
}

class _DiscardGuardState extends State<DiscardGuard> {
  /// The form's contents when it opened. Taken in initState, not lazily,
  /// or it would only be read when leaving, after the changes.
  late final String _atStart;

  @override
  void initState() {
    super.initState();
    _atStart = widget.snapshot();
  }

  Future<void> _askBeforeLeaving(bool didPop, Object? result) async {
    if (didPop) {
      return;
    }
    final navigator = Navigator.of(context);
    if (widget.snapshot() == _atStart) {
      navigator.pop(result);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('What you changed on this screen is not saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true) {
      navigator.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _askBeforeLeaving,
      child: widget.child,
    );
  }
}
