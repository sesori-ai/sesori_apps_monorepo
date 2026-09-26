import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  Widget buildApp({
    required String text,
    required bool isStreaming,
    String partId = "part-1",
    String messageId = "msg-1",
  }) {
    return MaterialApp(
      theme: buildPregoThemeData(brightness: Brightness.light),
      darkTheme: buildPregoThemeData(brightness: Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReasoningPartCard(
          text: text,
          isStreaming: isStreaming,
          partId: partId,
          messageId: messageId,
        ),
      ),
    );
  }

  /// A finished thought reads as one line: its label, then its preview.
  Finder finishedRow(String preview) => find.text("Thought $preview");

  group("empty state", () {
    testWidgets("returns SizedBox.shrink when text is empty and not streaming", (tester) async {
      await tester.pumpWidget(buildApp(text: "", isStreaming: false));
      await tester.pumpAndSettle();

      expect(find.byType(ReasoningPartCard), findsOneWidget);
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets("renders card when text is empty but streaming", (tester) async {
      await tester.pumpWidget(buildApp(text: "", isStreaming: true));
      await tester.pumpAndSettle();

      expect(find.byType(InkWell), findsOneWidget);
      expect(tester.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(44));
    });
  });

  group("completed (non-streaming) preview", () {
    testWidgets("shows first line of text when completed", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "First line of reasoning\n\nSecond paragraph here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(finishedRow("First line of reasoning"), findsOneWidget);
    });

    testWidgets("strips bold markdown from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "**Investigating how xyz works**\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(finishedRow("Investigating how xyz works"), findsOneWidget);
    });

    testWidgets("strips italic markdown from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "*Summarizing why abc is important*\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(finishedRow("Summarizing why abc is important"), findsOneWidget);
    });

    testWidgets("strips heading markdown from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "## Planning the approach\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(finishedRow("Planning the approach"), findsOneWidget);
    });

    testWidgets("strips inline code markdown from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "Checking `foo()` method\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(finishedRow("Checking foo() method"), findsOneWidget);
    });

    testWidgets("decodes HTML character references in preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "The user wants &quot;quoted text&quot;.\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(finishedRow('The user wants "quoted text".'), findsOneWidget);
    });

    testWidgets("preserves HTML character references inside inline code", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "The literal entity is `&quot;`.\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(finishedRow("The literal entity is &quot;."), findsOneWidget);
    });

    testWidgets("strips link markdown from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "See [docs](https://example.com)\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(finishedRow("See docs"), findsOneWidget);
    });

    testWidgets("removes images from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "Reviewing ![diagram](img.png)\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(finishedRow("Reviewing"), findsOneWidget);
    });

    testWidgets("handles mixed markdown in preview", (tester) async {
      await tester.pumpWidget(
        buildApp(
          text: "**Bold** and *italic* and `code` here\n\nDetails.",
          isStreaming: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(finishedRow("Bold and italic and code here"), findsOneWidget);
    });

    testWidgets("preview is limited to one line with ellipsis", (tester) async {
      await tester.pumpWidget(
        buildApp(
          text: "This is a very long first line that should definitely be truncated with ellipsis",
          isStreaming: false,
        ),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.textContaining("This is a very long"));
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets("skips leading empty lines", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "\n\nFirst real line\n\nSecond paragraph.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(finishedRow("First real line"), findsOneWidget);
    });

    testWidgets("preserves snake_case identifiers", (tester) async {
      await tester.pumpWidget(
        buildApp(
          text: "session_detail_cubit state management\n\nDetails here.",
          isStreaming: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(finishedRow("session_detail_cubit state management"), findsOneWidget);
    });
  });

  group("streaming preview", () {
    testWidgets("shows gradient-masked text preview when streaming", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "Streaming thought here\n\nMore content.", isStreaming: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShaderMask), findsOneWidget);
      expect(find.textContaining("Streaming thought here"), findsOneWidget);
    });
  });

  group("latest words", () {
    test("returns a short thought on one line", () {
      expect(ReasoningPartCard.latestWords(text: "short\n\nthought  here"), "short thought here");
    });

    test("keeps only the end of a long thought", () {
      final text = "${"a" * 800} newest words";

      expect(ReasoningPartCard.latestWords(text: text), "${"a" * 147} newest words");
    });

    test("never starts on an orphaned UTF-16 low surrogate", () {
      // The cut lands between the emoji's two code units.
      final text = "${"x" * 10}😀${"y" * 159}";

      expect(ReasoningPartCard.latestWords(text: text), "y" * 159);
    });
  });

  testWidgets("a streaming thought shows its latest words on one line", (tester) async {
    await tester.pumpWidget(buildApp(text: "${"older words " * 40}newest words", isStreaming: true));
    await tester.pumpAndSettle();

    final tail = find.textContaining("newest words");
    expect(tester.widget<Text>(tail).maxLines, 1);
    // The newest words stay in view at the row's end; the older start is cut.
    expect(tester.getRect(tail).right, closeTo(tester.getRect(find.byType(ReasoningPartCard)).right, 1));
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets("${brightness.name} a finished thought is one unboxed row", (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(buildApp(text: "Reviewing the next step", isStreaming: false));

      final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;
      final style = tester.widget<Text>(finishedRow("Reviewing the next step")).style;
      expect(style?.fontSize, 14);
      expect(style?.height, closeTo(20 / 14, 0.001));
      expect(style?.color, prego.colors.textSecondary);
      expect(style?.fontStyle, isNot(FontStyle.italic));
      expect(
        find.descendant(of: find.byType(ReasoningPartCard), matching: find.byType(Container)),
        findsNothing,
      );
      expect(find.byIcon(TablerRegular.chevron_right), findsNothing);
      expect(tester.widget<PregoAiLoader>(find.byType(PregoAiLoader)).animate, isFalse);
    });
  }

  testWidgets("streaming motion stops on completion and preserves the latest preview", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
    await tester.pumpWidget(buildApp(text: "First thought", isStreaming: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PregoShimmer), findsOneWidget);
    expect(tester.widget<PregoAiLoader>(find.byType(PregoAiLoader)).animate, isTrue);

    await tester.pumpWidget(buildApp(text: "**Updated thought**\n\nFinished detail.", isStreaming: false));
    await tester.pumpAndSettle();
    expect(finishedRow("Updated thought"), findsOneWidget);
    expect(find.byType(PregoShimmer), findsNothing);
    expect(tester.widget<PregoAiLoader>(find.byType(PregoAiLoader)).animate, isFalse);
  });

  testWidgets("reduced motion keeps the streaming status accessible and still", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildApp(text: "Current thought", isStreaming: true));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r"^Thinking\.\.\.\nCurrent thought$")), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(MergeSemantics)),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(
      find.descendant(of: find.byType(PregoShimmer), matching: find.byType(ShaderMask)),
      findsNothing,
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    semantics.dispose();
  });

  testWidgets("empty streaming reasoning remains a named disclosure", (tester) async {
    await tester.pumpWidget(buildApp(text: "", isStreaming: true));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(MergeSemantics)),
      isSemantics(label: "Thinking...", isButton: true, hasTapAction: true),
    );
  });

  testWidgets("narrow panes with large text keep the disclosure and preview inside the row", (tester) async {
    tester.view.physicalSize = const Size(240, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final streaming in [false, true]) {
      await tester.pumpWidget(buildApp(text: "A long thought about the next step " * 60, isStreaming: streaming));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(InkWell)).right, lessThanOrEqualTo(240));
      expect(tester.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(44));
    }
  });

  group("header text", () {
    testWidgets("shows 'Thought' when not streaming", (tester) async {
      await tester.pumpWidget(buildApp(text: "Some thought", isStreaming: false));
      await tester.pumpAndSettle();

      expect(finishedRow("Some thought"), findsOneWidget);
    });

    testWidgets("shows 'Thinking...' when streaming", (tester) async {
      await tester.pumpWidget(buildApp(text: "Some thought", isStreaming: true));
      await tester.pumpAndSettle();

      expect(find.text("Thinking..."), findsOneWidget);
    });
  });
}
