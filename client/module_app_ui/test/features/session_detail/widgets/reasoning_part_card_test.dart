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

      expect(find.text("First line of reasoning"), findsOneWidget);
    });

    testWidgets("strips bold markdown from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "**Investigating how xyz works**\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(find.text("Investigating how xyz works"), findsOneWidget);
    });

    testWidgets("strips italic markdown from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "*Summarizing why abc is important*\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(find.text("Summarizing why abc is important"), findsOneWidget);
    });

    testWidgets("strips heading markdown from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "## Planning the approach\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(find.text("Planning the approach"), findsOneWidget);
    });

    testWidgets("strips inline code markdown from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "Checking `foo()` method\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(find.text("Checking foo() method"), findsOneWidget);
    });

    testWidgets("decodes HTML character references in preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "The user wants &quot;quoted text&quot;.\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('The user wants "quoted text".'), findsOneWidget);
    });

    testWidgets("preserves HTML character references inside inline code", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "The literal entity is `&quot;`.\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(find.text("The literal entity is &quot;."), findsOneWidget);
    });

    testWidgets("strips link markdown from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "See [docs](https://example.com)\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(find.text("See docs"), findsOneWidget);
    });

    testWidgets("removes images from preview", (tester) async {
      await tester.pumpWidget(
        buildApp(text: "Reviewing ![diagram](img.png)\n\nDetails here.", isStreaming: false),
      );
      await tester.pumpAndSettle();

      expect(find.text("Reviewing"), findsOneWidget);
    });

    testWidgets("handles mixed markdown in preview", (tester) async {
      await tester.pumpWidget(
        buildApp(
          text: "**Bold** and *italic* and `code` here\n\nDetails.",
          isStreaming: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Bold and italic and code here"), findsOneWidget);
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

      expect(find.text("First real line"), findsOneWidget);
    });

    testWidgets("preserves snake_case identifiers", (tester) async {
      await tester.pumpWidget(
        buildApp(
          text: "session_detail_cubit state management\n\nDetails here.",
          isStreaming: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("session_detail_cubit state management"), findsOneWidget);
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

  group("streaming tail slicing", () {
    test("returns text under the tail budget unchanged", () {
      expect(ReasoningPartCard.streamingTail(text: "short thought"), "short thought");
    });

    test("starts the slice after the first newline inside the tail window", () {
      final text = "${"a" * 800}\n${"b" * 400}";

      expect(ReasoningPartCard.streamingTail(text: text), "b" * 400);
    });

    test("keeps the whole slice when a newline near the end would empty the preview", () {
      // The only newline in the window sits 10 characters from the end;
      // aligning to it would collapse the 56px preview to a near-blank
      // sliver showing just those characters.
      final text = "${"a" * 1000}\n${"b" * 10}";

      expect(ReasoningPartCard.streamingTail(text: text), "${"a" * 689}\n${"b" * 10}");
    });

    test("never starts the slice on an orphaned UTF-16 low surrogate", () {
      // Position an emoji so the tail cut lands exactly between its two
      // UTF-16 code units; no newline follows, so the raw slice would
      // otherwise begin with a malformed lone low surrogate.
      final text = "${"x" * 700}😀${"y" * 699}";

      expect(ReasoningPartCard.streamingTail(text: text), "y" * 699);
    });
  });

  for (final brightness in Brightness.values) {
    testWidgets("${brightness.name} reasoning uses unboxed activity typography", (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpWidget(buildApp(text: "Reviewing the next step", isStreaming: false));

      final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;
      for (final text in ["Thought", "Reviewing the next step"]) {
        final style = tester.widget<Text>(find.text(text)).style!;
        expect(style.fontSize, 14);
        expect(style.height, closeTo(20 / 14, 0.001));
        expect(style.color, prego.colors.textSecondary);
        expect(style.fontStyle, isNot(FontStyle.italic));
      }
      expect(
        find.descendant(of: find.byType(ReasoningPartCard), matching: find.byType(Container)),
        findsNothing,
      );
      expect(find.byIcon(TablerRegular.chevron_right), findsOneWidget);
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
    expect(find.text("Thought"), findsOneWidget);
    expect(find.text("Updated thought"), findsOneWidget);
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
      expect(tester.getRect(find.byIcon(TablerRegular.chevron_right)).right, lessThanOrEqualTo(240));
      expect(tester.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(44));
    }
  });

  group("header text", () {
    testWidgets("shows 'Thought' when not streaming", (tester) async {
      await tester.pumpWidget(buildApp(text: "Some thought", isStreaming: false));
      await tester.pumpAndSettle();

      expect(find.text("Thought"), findsOneWidget);
    });

    testWidgets("shows 'Thinking...' when streaming", (tester) async {
      await tester.pumpWidget(buildApp(text: "Some thought", isStreaming: true));
      await tester.pumpAndSettle();

      expect(find.text("Thinking..."), findsOneWidget);
    });
  });
}
