import "package:flutter/material.dart";

import "core/di/injection.dart";
import "core/extensions/build_context_x.dart";
import "core/routing/app_router.dart";
import "core/routing/deep_link_service.dart";
import "core/widgets/connection_overlay.dart";
import "l10n/app_localizations.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  getIt<DeepLinkService>().init();
  runApp(const SesoriApp());
}

class SesoriApp extends StatelessWidget {
  const SesoriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.loc.appTitle,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      builder: (context, child) => ConnectionOverlay(
        router: appRouter,
        child: child!,
      ),
    );
  }
}
