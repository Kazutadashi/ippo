// SPDX-License-Identifier: GPL-3.0-or-later

/// Saving from a screen, and telling the user if it failed.
library;

import 'package:material_ui/material_ui.dart';

import 'storage/data_folder.dart';

/// Runs [save] and returns true if it worked.
///
/// If saving fails with a [DataFolderException], the user sees a message
/// at the bottom of the screen and this returns false. Errors are never
/// swallowed silently.
Future<bool> saveOrShowError(
  BuildContext context,
  Future<void> Function() save,
) async {
  try {
    await save();
    return true;
  } on DataFolderException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Not saved: ${error.message}')));
    }
    return false;
  }
}
