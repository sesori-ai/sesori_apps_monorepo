import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_mobile/features/session_list/archived_sessions_artwork.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  const base = "assets/images/archived_sessions_empty";

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
          // ThemeData reads brightness from the color scheme, which is what
          // the product-owned artwork uses to select its export.
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
              SliverFillRemaining(
                hasScrollBody: false,
                child: SessionArchivedEmptyState(artwork: ArchivedSessionsArtwork()),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String emptyLabel(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(SessionArchivedEmptyState)))!.sessionListEmptyArchived;

  String artworkOf(WidgetTester tester) => (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

  testWidgets("renders the archive artwork above the label", (tester) async {
    await pumpEmptyState(tester);

    expect(find.byKey(const Key("session-empty-archive")), findsOneWidget);
    expect(find.text(emptyLabel(tester)), findsOneWidget);
  });

  testWidgets("keeps the artwork a fixed size under system text scaling", (tester) async {
    await pumpEmptyState(tester);
    final unscaled = tester.getSize(find.byKey(const Key("session-empty-archive")));

    await pumpEmptyState(tester, textScaler: const TextScaler.linear(3));

    expect(tester.getSize(find.byKey(const Key("session-empty-archive"))), unscaled);
  });

  group("the artwork it draws", () {
    // Left to one export, the boxes would be a white slab on a dark surface.
    testWidgets("uses the light stack in light mode", (tester) async {
      await pumpEmptyState(tester);

      expect(artworkOf(tester), "$base/archive_stack-light.png");
    });

    testWidgets("uses the dark stack in dark mode", (tester) async {
      await pumpEmptyState(tester, brightness: Brightness.dark);

      expect(artworkOf(tester), "$base/archive_stack-dark.png");
    });
  });
}
