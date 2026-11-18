// SPDX-License-Identifier: GPL-3.0-or-later

/// The message with an "Undo" button shown after deleting something.
library;

import 'package:material_ui/material_ui.dart';

/// How long the undo message stays before it hides itself.
const Duration undoMessageDuration = Duration(seconds: 5);

/// Shows [message] at the bottom of the screen with an "Undo" button
/// that calls [onUndo].
///
/// The message hides itself after [undoMessageDuration], and has an ✕ to
/// close it straight away. (Flutter would otherwise keep a message with
/// a button on screen until it is tapped.)
///
/// [messenger] is passed in, rather than looked up here, so it can be
/// taken before the screen that deleted something closes.
void showUndoMessage(
  ScaffoldMessengerState messenger, {
  required String message,
  required VoidCallback onUndo,
}) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: undoMessageDuration,
      persist: false,
      showCloseIcon: true,
      action: SnackBarAction(label: 'Undo', onPressed: onUndo),
    ),
  );
}
