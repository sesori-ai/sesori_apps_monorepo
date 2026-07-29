import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/features/session_list/session_archived_empty_state.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  // Mirrors production hosting: the empty state renders inside a
  // SliverFillRemaining(hasScrollBody: false) in the sessions scroll view.
  Future<void> pumpEmptyState(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    TextScaler textScaler = TextScaler.noScaling,
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverFillRemaining(hasScrollBody: false, child: SessionArchivedEmptyState()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String emptyLabel(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(SessionArchivedEmptyState)))!.sessionListEmptyArchived;

  SvgAssetLoader loaderOf(WidgetTester tester) =>
      tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader as SvgAssetLoader;

  testWidgets("renders the archive artwork above the label", (tester) async {
    await pumpEmptyState(tester);

    expect(find.byKey(const Key("session-empty-archive")), findsOneWidget);
    expect(find.text(emptyLabel(tester)), findsOneWidget);
    expect(loaderOf(tester).assetName, "assets/images/archived_sessions_empty.svg");
    expect(tester.takeException(), isNull);
  });

  testWidgets("keeps the artwork a fixed size under system text scaling", (tester) async {
    await pumpEmptyState(tester);
    final unscaled = tester.getSize(find.byKey(const Key("session-empty-archive")));

    await pumpEmptyState(tester, textScaler: const TextScaler.linear(3));

    expect(tester.getSize(find.byKey(const Key("session-empty-archive"))), unscaled);
    expect(tester.takeException(), isNull);
  });

  group("the colours the artwork is drawn in", () {
    testWidgets("stay as exported under the light theme", (tester) async {
      await pumpEmptyState(tester);

      // A no-op in light mode: the export already carries these values.
      final mapper = loaderOf(tester).colorMapper!;
      final colors = PregoDesignSystem.light.colors;
      expect(mapper.substitute(null, "path", "fill", const Color(0xFFFFFFFF)), colors.bgSurface4);
      expect(mapper.substitute(null, "stop", "stop-color", const Color(0xFFF0F0F0)), colors.bgSurface1);
      expect(mapper.substitute(null, "path", "fill", const Color(0xFF141414)), colors.textPrimary);
    });

    testWidgets("flip with the dark theme", (tester) async {
      await pumpEmptyState(tester, brightness: Brightness.dark);

      // Left alone, the boxes would be a white slab and the glyph invisible.
      final mapper = loaderOf(tester).colorMapper!;
      final colors = PregoDesignSystem.dark.colors;
      expect(mapper.substitute(null, "path", "fill", const Color(0xFFFFFFFF)), colors.bgSurface4);
      expect(mapper.substitute(null, "stop", "stop-color", const Color(0xFFF0F0F0)), colors.bgSurface1);
      expect(mapper.substitute(null, "path", "fill", const Color(0xFF141414)), colors.textPrimary);
      expect(tester.takeException(), isNull);
    });
  });
}
