import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/compaction_part_widget.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// One of each step kind, with its row text, as a group's panel lists them.
const _steps = <(Widget, String)>[
  (
    ReasoningPartCard(text: "Weighing the options", isStreaming: false, partId: "r", messageId: "m"),
    "Thought Weighing the options",
  ),
  (
    ToolPartWidget(
      part: MessagePartTool(
        id: "read",
        sessionID: "s",
        messageID: "m",
        tool: "read",
        state: ToolState(
          status: ToolStatus.completed,
          title: "notes.md",
          shellCommand: null,
          output: null,
          error: null,
        ),
      ),
    ),
    "Read notes.md",
  ),
  (
    ToolPartWidget(
      part: MessagePartTool(
        id: "grep",
        sessionID: "s",
        messageID: "m",
        tool: "grep",
        state: ToolState(status: ToolStatus.running, title: "timeout", shellCommand: null, output: null, error: null),
      ),
    ),
    "Grep timeout",
  ),
  (
    ToolPartWidget(
      part: MessagePartTool(
        id: "bash",
        sessionID: "s",
        messageID: "m",
        tool: "bash",
        state: ToolState(
          status: ToolStatus.completed,
          title: null,
          shellCommand: "make test",
          output: "ok",
          error: null,
        ),
      ),
    ),
    r"Ran $ make test",
  ),
  (
    SubtaskPartWidget(
      projectId: "p",
      part: MessagePartSubtask(
        id: "agent",
        sessionID: "s",
        messageID: "m",
        description: "Survey the screens",
        agent: "explore",
        taskState: null,
        childSessionID: "child",
      ),
      childSession: null,
      status: TranscriptStepStatus.finished,
    ),
    "Explore Survey the screens",
  ),
  (CompactionPartWidget(summary: "Carried forward"), "Context compacted"),
];

void main() {
  for (final (surface, density) in [("phone", VisualDensity.standard), ("desktop", VisualDensity.compact)]) {
    testWidgets("every step kind lines up in one row layout on the $surface", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light).copyWith(visualDensity: density),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final (step, _) in _steps) step],
            ),
          ),
        ),
      );

      // A button's height at this density, plus a step's own spacing.
      final height = 44 + density.baseSizeAdjustment.dy + 8;
      for (final (step, text) in _steps) {
        final part = find.byWidget(step);
        final origin = tester.getTopLeft(part);
        final row = find.descendant(of: part, matching: find.byType(TranscriptStepRow));
        final leading = find
            .descendant(
              of: row,
              matching: find.byWidgetPredicate((widget) => widget is Icon || widget is PregoAiLoader),
            )
            .first;
        final label = find.descendant(of: row, matching: find.text(text));

        expect(tester.getSize(part).height, height, reason: text);
        expect(tester.getCenter(leading) - origin, Offset(10, height / 2), reason: text);
        expect(tester.getTopLeft(label) - origin, Offset(28, height / 2 - 10), reason: text);
        expect(
          tester.widget<Text>(label).textSpan,
          isA<TextSpan>().having(
            (span) => span.children?.first.style?.fontWeight,
            "label weight",
            PregoDesignSystem.light.textTheme.textSm.bold.fontWeight,
          ),
          reason: text,
        );
      }
      // The four other rows lead with an icon; the thought and the live row
      // with the sparkle.
      final icons = tester.widgetList<Icon>(
        find.descendant(of: find.byType(TranscriptStepRow), matching: find.byType(Icon)),
      );
      expect(icons.map((icon) => icon.size), List.filled(4, PregoIconSize.sm));
    });
  }
}
