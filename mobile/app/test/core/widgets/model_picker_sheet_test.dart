import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_mobile/core/widgets/model_picker_sheet.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

ProviderModel _model({
  required String id,
  required String name,
  String? family,
  DateTime? releaseDate,
}) {
  return ProviderModel(
    id: id,
    providerID: "test-provider",
    name: name,
    variants: const [],
    family: family,
    releaseDate: releaseDate,
  );
}

List<ProviderInfo> _providers() {
  return [
    ProviderInfo(
      id: "anthropic",
      name: "Anthropic",
      models: {
        "claude-new": _model(
          id: "claude-new",
          name: "Claude Sonnet (latest)",
          family: "claude",
          releaseDate: DateTime(2026),
        ),
        "claude-old": _model(
          id: "claude-old",
          name: "Claude Opus Classic",
          family: "claude",
          releaseDate: DateTime(2024),
        ),
      },
      defaultModelID: null,
    ),
    ProviderInfo(
      id: "zeta",
      name: "Zeta AI",
      models: {
        "z-1": _model(id: "z-1", name: "Zeta One", releaseDate: DateTime(2025)),
      },
      defaultModelID: null,
    ),
  ];
}

Widget _buildApp({
  required void Function({required String providerID, required String modelID}) onModelChanged,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => Scaffold(
          body: FilledButton(
            onPressed: () => ModelPickerSheet.show(
              context,
              providers: _providers(),
              selectedProviderID: "anthropic",
              selectedModelID: "claude-new",
              onModelChanged: onModelChanged,
            ),
            child: const Text("Open picker"),
          ),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(
      extensions: [ZyraDesignSystem.light],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

/// Opens the picker. The section computation runs in a real isolate via
/// compute(), which the fake-async test clock cannot settle on its own, so
/// the sheet deterministically shows its loading state at this point.
Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text("Open picker"));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Lets the compute() isolate finish and the sheet rebuild with its result.
///
/// Alternates between [WidgetTester.runAsync] (so the isolate's real-time
/// message round-trip can happen) and [WidgetTester.pump] (so the fake-async
/// clock processes the resulting setState rebuild). pumpAndSettle cannot be
/// used: the isolate communication leaves pending work the fake-async clock
/// never resolves on its own.
Future<void> _waitForModels(WidgetTester tester, {required Finder until}) async {
  for (var i = 0; i < 40 && until.evaluate().isEmpty; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }
  expect(until, findsWidgets, reason: "model picker content did not finish loading");
}

void main() {
  testWidgets("opens with a loading indicator, then shows default models per family", (tester) async {
    await tester.pumpWidget(_buildApp(onModelChanged: ({required providerID, required modelID}) {}));

    await _openPicker(tester);

    // The sheet is open (title visible) but the model list is still being
    // computed in the background isolate: loading indicator, no models yet.
    expect(find.text("Select Model"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text("Claude Sonnet"), findsNothing);

    await _waitForModels(tester, until: find.text("Claude Sonnet"));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("Anthropic"), findsOneWidget);
    expect(find.text("Zeta AI"), findsOneWidget);
    expect(find.text("Zeta One"), findsOneWidget);
    // Only the family representative is visible by default; the "(latest)"
    // marker is stripped from the display name.
    expect(find.text("Claude Opus Classic"), findsNothing);
  });

  testWidgets("search reveals non-default family members and filters providers", (tester) async {
    await tester.pumpWidget(_buildApp(onModelChanged: ({required providerID, required modelID}) {}));

    await _openPicker(tester);
    await _waitForModels(tester, until: find.text("Claude Sonnet"));

    await tester.enterText(find.byType(TextField), "Opus");
    await tester.pump();

    expect(find.text("Claude Opus Classic"), findsOneWidget);
    expect(find.text("Claude Sonnet"), findsNothing);
    expect(find.text("Zeta One"), findsNothing);
  });

  testWidgets("tapping a model returns the selection and closes the sheet", (tester) async {
    String? selectedProviderID;
    String? selectedModelID;
    await tester.pumpWidget(
      _buildApp(
        onModelChanged: ({required providerID, required modelID}) {
          selectedProviderID = providerID;
          selectedModelID = modelID;
        },
      ),
    );

    await _openPicker(tester);
    await _waitForModels(tester, until: find.text("Zeta One"));
    // Let the sheet's entrance animation finish: while the route is still
    // animating, the navigator ignores pointer events on its content.
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text("Zeta One"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(selectedProviderID, "zeta");
    expect(selectedModelID, "z-1");
    expect(find.text("Select Model"), findsNothing);
  });
}
