import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";

import "injection.config.dart";

// Phase 4 of the desktop 4-phase DI init (see client/AGENTS.md):
//   1. Desktop platform adapters (client/desktop getIt.init())
//   2. configureAuthDependencies
//   3. configureCoreDependencies
//   4. configureDesktopCoreDependencies ← THIS
//
// Desktop services, repositories, and trackers register HERE (via annotations
// in this package), never in the client/desktop shell.
@InjectableInit()
void configureDesktopCoreDependencies(GetIt getIt) => getIt.init();
