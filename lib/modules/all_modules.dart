// SPDX-License-Identifier: GPL-3.0-or-later

/// The list of modules the app shows.
///
/// This is the only place that knows every module. To add a module,
/// create its folder in `lib/modules/` and add it to this list; nothing
/// else needs to change.
library;

import '../core/module.dart';
import 'food/food_module.dart';

/// Every module, in the order shown on the home screen.
const List<IppoModule> allModules = [FoodModule()];
