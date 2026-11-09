import "package:flutter/rendering.dart";
import "package:flutter/services.dart" show FontLoader, rootBundle;
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_list/session_list_headings.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/module_prego.dart";

/// The desktop sidebar at its largest text size (Larger, 130%): rows and
/// headings grow with their text rather than overflowing or cropping a line.
void main() {
  final now = DateTime.now().millisecondsSinceEpoch;

  // The real face: the test font draws every glyph a full em wide, which
  // would overflow lines that fit in the app.
  setUpAll(() async {
    final font = FontLoader(PregoTextTheme.fontFamily);
    for (final weight in ["Regular", "Medium", "Bold"]) {
      font.addFont(rootBundle.load("packages/theme_prego/assets/fonts/SatoshiPrego/SatoshiPrego-$weight.otf"));
    }
    await font.load();
  });

  SessionTile tile({
    required String title,
    String? projectLabel,
    bool isRunning = false,
    bool unseen = false,
    bool awaitingInput = false,
    bool isRetrying = false,
    int backgroundTaskCount = 0,
  }) => SessionTile(
    session: testSession(title: title, updatedAt: now),
    projectLabel: projectLabel,
    isArchived: false,
    isRunning: isRunning,
    unseen: unseen,
    selected: false,
    awaitingInput: awaitingInput,
    isRetrying: isRetrying,
    backgroundTaskCount: backgroundTaskCount,
    onTap: () {},
    menuEntries: () => const [],
    onArchive: () {},
    onDelete: () {},
    onToggleUnread: () {},
  );

  testWidgets("sidebar rows and headings hold their text at 130% under a pointer", (tester) async {
    tester.view.physicalSize = const Size(280, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.desktopLight]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(
          child: PregoInteractionScope(
            mode: PregoInteractionMode.pointer,
            child: Column(
              children: [
                const SessionListHeading(heading: "Today", isFirst: true),
                tile(title: "Refactor the bridge supervisor", isRunning: true, projectLabel: "sesori"),
                tile(title: "Answer the migration question", awaitingInput: true, projectLabel: "sesori"),
                tile(title: "Unread reply", unseen: true),
                tile(title: "Flaky upload", isRetrying: true, backgroundTaskCount: 2, projectLabel: "relay"),
                const SessionListHeading(heading: "Yesterday", isFirst: false),
                tile(title: "Quiet session"),
              ],
            ),
          ),
        ),
      ),
    );
    // A running row twinkles forever, so fixed pumps rather than pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    final cropped = [
      for (final paragraph in tester.renderObjectList<RenderParagraph>(find.byType(RichText)))
        if (paragraph.getMinIntrinsicHeight(paragraph.size.width) > paragraph.size.height + 0.01)
          paragraph.text.toPlainText(),
    ];
    expect(cropped, isEmpty, reason: "these lines are shorter than their text");
    // The scale really reached them: a meta line is taller than at 1x.
    expect(tester.getSize(find.text("Today")).height, greaterThan(16));
  });
}
