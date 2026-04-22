import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_mobile/core/widgets/effort_picker_sheet.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";

Widget _buildApp({required ValueChanged<SessionEffort> onEffortChanged}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => Scaffold(
          body: FilledButton(
            onPressed: () => EffortPickerSheet.show(
              context,
              selectedEffort: SessionEffort.medium,
              onEffortChanged: onEffortChanged,
            ),
            child: const Text("Open picker"),
          ),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  testWidgets("shows all three effort options and returns the tapped selection", (tester) async {
    SessionEffort? selectedEffort;

    await tester.pumpWidget(
      _buildApp(onEffortChanged: (effort) => selectedEffort = effort),
    );

    await tester.tap(find.text("Open picker"));
    await tester.pumpAndSettle();

    expect(find.text("Effort"), findsOneWidget);
    expect(find.text("Low"), findsOneWidget);
    expect(find.text("Medium"), findsOneWidget);
    expect(find.text("Max"), findsOneWidget);

    await tester.tap(find.text("Low"));
    await tester.pumpAndSettle();

    expect(selectedEffort, SessionEffort.low);
    expect(find.text("Effort"), findsNothing);
  });
}
