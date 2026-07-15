import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/features/session_list/session_empty_state.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  // Mirrors production hosting: the empty state renders inside a
  // SliverFillRemaining(hasScrollBody: false) in the sessions scroll view.
  Future<void> pumpEmptyState(
    WidgetTester tester, {
    required String? projectName,
    Brightness brightness = Brightness.light,
  }) async {
    final isDark = brightness == Brightness.dark;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: (isDark ? PregoColors.dark : PregoColors.light).toFlutterColorScheme(),
          textTheme: (isDark ? PregoTextTheme.dark : PregoTextTheme.light).asFlutterTextTheme(),
          extensions: [isDark ? PregoDesignSystem.dark : PregoDesignSystem.light],
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: SessionEmptyState(projectName: projectName),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String emptyTitle(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(SessionEmptyState)))!.sessionListEmptyTitle;

  testWidgets("renders the terminal glyph, headline, and project chip", (tester) async {
    await pumpEmptyState(tester, projectName: "Sesori_app_monorepo");

    expect(find.text(emptyTitle(tester)), findsOneWidget);
    expect(find.byKey(const Key("session-empty-terminal")), findsOneWidget);
    expect(find.byIcon(TablerSolid.brand_github), findsOneWidget);
    expect(find.text("Sesori_app_monorepo"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("hides the project chip when there is no project name", (tester) async {
    await pumpEmptyState(tester, projectName: null);

    expect(find.text(emptyTitle(tester)), findsOneWidget);
    expect(find.byKey(const Key("session-empty-terminal")), findsOneWidget);
    expect(find.byIcon(TablerSolid.brand_github), findsNothing);
  });

  testWidgets("renders without overflow in dark mode", (tester) async {
    await pumpEmptyState(
      tester,
      projectName: "Sesori_app_monorepo",
      brightness: Brightness.dark,
    );

    expect(find.byKey(const Key("session-empty-terminal")), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
