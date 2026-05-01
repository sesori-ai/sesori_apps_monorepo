import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/features/session_detail/widgets/reasoning_part_card.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";

void main() {
  Widget buildApp({
    required String text,
    required bool isStreaming,
    String partId = "part-1",
    String messageId = "msg-1",
  }) {
    return MaterialApp(
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
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets("renders card when text is empty but streaming", (tester) async {
      await tester.pumpWidget(buildApp(text: "", isStreaming: true));
      await tester.pumpAndSettle();

      expect(find.byType(GestureDetector), findsOneWidget);
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
