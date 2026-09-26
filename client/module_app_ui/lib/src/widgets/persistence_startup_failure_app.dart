import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "../l10n/app_localizations.dart";

/// A standalone recovery root: no DI, stored preferences, analytics or retry job.
class const PersistenceStartupFailureApp({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildPregoThemeData(brightness: Brightness.light),
    darkTheme: buildPregoThemeData(brightness: Brightness.dark),
    home: Builder(
      builder: (context) {
        final prego = context.prego;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(prego.spacing.xl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(TablerRegular.alert_circle, color: prego.colors.fgErrorPrimary, size: 40),
                      SizedBox(height: prego.spacing.xl),
                      Text(
                        context.loc.persistenceStartupFailureTitle,
                        style: prego.textTheme.textXl.bold.copyWith(color: prego.colors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: prego.spacing.md),
                      Text(
                        context.loc.persistenceStartupFailureDescription,
                        style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
