import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/compaction_part_widget.dart";
import "package:theme_prego/module_prego.dart";

const _shortSummary = "## Carried forward\n\n- Keep the relay contract unchanged\n- Retry with a capped backoff";

/// Long enough to be worth deferring past the modal's entry transition.
final _longSummary =
    "$_shortSummary\n${List.filled(100, "- Another carried-forward decision and its reasoning").join("\n")}";

Widget _app({required PregoInteractionMode mode, required String summary}) {
  return PregoInteractionScope(
    mode: mode,
    child: MaterialApp(
      theme: buildPregoThemeData(brightness: Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SessionDetailPresentationScope(
        messageImageRepository: () => throw UnimplementedError(),
        imageSaver: () => throw UnimplementedError(),
        imageClipboard: () => throw UnimplementedError(),
        imageSharer: () => throw UnimplementedError(),
        canShareImages: false,
        openExternalLink: ({required url, required mode}) async => false,
        openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
        openHarnessSettings: () {},
        openBridgeSettings: () {},
        child: Scaffold(body: CompactionPartWidget(summary: summary)),
      ),
    ),
  );
}

void main() {
  for (final mode in PregoInteractionMode.values) {
    testWidgets("the ${mode.name} modal opens behind a spinner, then shows the summary", (tester) async {
      await tester.pumpWidget(_app(mode: mode, summary: _longSummary));

      await tester.tap(find.text("Context compacted"));
      await tester.pump();

      // The modal's first frame holds only a spinner, so it stays cheap.
      expect(find.text("Compaction summary"), findsOneWidget);
      expect(find.byType(PregoActivityIndicator), findsOneWidget);
      expect(find.byType(MarkdownBody), findsNothing);

      // The summary waits out the entry transition.
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(MarkdownBody), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(PregoActivityIndicator), findsNothing);
      expect(find.textContaining("Keep the relay contract unchanged", findRichText: true), findsOneWidget);
    });
  }

  testWidgets("under reduced motion the modal shows the summary at once", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_app(mode: PregoInteractionMode.pointer, summary: _longSummary));

    await tester.tap(find.text("Context compacted"));
    await tester.pump();

    expect(find.byType(PregoActivityIndicator), findsNothing);
    expect(find.textContaining("Keep the relay contract unchanged", findRichText: true), findsOneWidget);
  });

  testWidgets("a short summary shows at once, without a spinner", (tester) async {
    await tester.pumpWidget(_app(mode: PregoInteractionMode.pointer, summary: _shortSummary));

    await tester.tap(find.text("Context compacted"));
    await tester.pump();

    expect(find.byType(PregoActivityIndicator), findsNothing);
    expect(find.textContaining("Keep the relay contract unchanged", findRichText: true), findsOneWidget);
  });
}
