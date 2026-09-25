import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_rolling_line.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

Widget _line({required List<TranscriptLineSegment> segments, bool disableAnimations = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Align(
      alignment: Alignment.topLeft,
      child: TranscriptRollingLine(
        segments: segments,
        style: const TextStyle(fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
    ),
  ),
);

const _thought = (key: TranscriptStepKind.thinking, text: "Thought");

double _width(WidgetTester tester) => tester.getSize(find.byType(TranscriptRollingLine)).width;

void main() {
  testWidgets("a changed count rolls only what changed and eases the line's width", (tester) async {
    await tester.pumpWidget(_line(segments: [_thought, (key: TranscriptStepKind.read, text: " · read 9 files")]));
    final before = _width(tester);

    await tester.pumpWidget(_line(segments: [_thought, (key: TranscriptStepKind.read, text: " · read 10 files")]));
    await tester.pump(const Duration(milliseconds: 100));

    // The unchanged text holds still while the number rolls up and away.
    expect(find.text("Thought"), findsOneWidget);
    expect(find.text(" · read "), findsOneWidget);
    expect(find.text(" files"), findsOneWidget);
    expect(tester.getTopLeft(find.text("10")).dy, greaterThan(tester.getTopLeft(find.text("9")).dy));
    final midway = _width(tester);

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text("Thought · read 10 files"), findsOneWidget);
    expect(midway, inExclusiveRange(before, _width(tester)));
  });

  testWidgets("a new segment wipes in and the line rests as one text", (tester) async {
    await tester.pumpWidget(_line(segments: [_thought]));
    final before = _width(tester);

    await tester.pumpWidget(_line(segments: [_thought, (key: TranscriptStepKind.command, text: " · ran 1 command")]));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(" · ran 1 command"), findsOneWidget);
    final midway = _width(tester);

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text("Thought · ran 1 command"), findsOneWidget);
    expect(midway, inExclusiveRange(before, _width(tester)));
  });

  testWidgets("a rolling line reads as the line it is heading to", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_line(segments: [(key: TranscriptStepKind.read, text: "read 2 files")]));
    await tester.pumpWidget(_line(segments: [(key: TranscriptStepKind.read, text: "read 3 files")]));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text("2"), findsOneWidget);
    expect(find.bySemanticsLabel("read 3 files"), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp("2")), findsNothing);
    semantics.dispose();
  });

  testWidgets("reduced motion changes the line at once", (tester) async {
    await tester.pumpWidget(
      _line(segments: [(key: TranscriptStepKind.read, text: "read 2 files")], disableAnimations: true),
    );
    await tester.pumpWidget(
      _line(segments: [(key: TranscriptStepKind.read, text: "read 3 files")], disableAnimations: true),
    );

    expect(find.text("read 3 files"), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
