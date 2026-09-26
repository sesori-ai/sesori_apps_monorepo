import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_turn_stub.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

const _opener = MessageWithParts(
  info: Message.user(promptId: null, id: "u1", sessionID: "session-1", agent: null, time: null),
  parts: [],
);

TranscriptTurnSummary _summary({required int steps, required TranscriptTurnOutcome outcome}) =>
    TranscriptTurnSummary(steps: steps, outcome: outcome);

TranscriptTurn _promptTurn({required int steps, required Duration? duration, required TranscriptTurnOutcome outcome}) =>
    TranscriptPromptTurn(
      opener: _opener,
      duration: duration,
      messageIds: const ["u1"],
      summary: _summary(steps: steps, outcome: outcome),
    );

void main() {
  const done = TranscriptTurnDone(answerLine: "Fixed the build");
  const doneQuietly = TranscriptTurnDone(answerLine: null);
  const running = TranscriptTurnRunning();
  final cases = <String, TranscriptTurn>{
    "3 steps · 1m 02s — Fixed the build": _promptTurn(
      steps: 3,
      duration: const Duration(seconds: 62),
      outcome: done,
    ),
    "1 step · 42s": _promptTurn(steps: 1, duration: const Duration(seconds: 42), outcome: doneQuietly),
    "2 steps · 1h 05m 30s": _promptTurn(steps: 2, duration: const Duration(minutes: 65, seconds: 30), outcome: doneQuietly),
    "No steps — Fixed the build": _promptTurn(steps: 0, duration: null, outcome: done),
    "3 steps": _promptTurn(steps: 3, duration: null, outcome: doneQuietly),
    "Running": _promptTurn(steps: 0, duration: null, outcome: running),
    "Running · step 4": _promptTurn(steps: 4, duration: const Duration(seconds: 9), outcome: running),
    "Ended with an error · Rate limit reached": _promptTurn(
      steps: 2,
      duration: null,
      outcome: const TranscriptTurnFailed(errorLine: "Rate limit reached"),
    ),
    "Ended with an error": _promptTurn(steps: 2, duration: null, outcome: const TranscriptTurnFailed(errorLine: null)),
    "Earlier turn, partly loaded · 3 steps": TranscriptPartialTurn(
      messageIds: const ["a0"],
      summary: _summary(steps: 3, outcome: running),
    ),
    "Before the first prompt · 1 step": TranscriptPreamble(
      messageIds: const ["a0"],
      summary: _summary(steps: 1, outcome: doneQuietly),
    ),
  };
  for (final MapEntry(key: expected, value: turn) in cases.entries) {
    test("a folded turn reads: $expected", () {
      expect(TranscriptTurnStub.label(loc: AppLocalizationsEn(), turn: turn), expected);
    });
  }

  testWidgets("leads with the outcome's glyph and reads its line to screen readers", (tester) async {
    final semantics = tester.ensureSemantics();
    const shown = {"Running · step 4", "Ended with an error", "3 steps"};
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              for (final MapEntry(key: label, value: turn) in cases.entries)
                if (shown.contains(label)) TranscriptTurnStub(turn: turn, onTap: () {}),
            ],
          ),
        ),
      ),
    );
    // The running sparkle turns forever, so the test never settles.
    await tester.pump();

    Finder glyphOf(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(TranscriptTurnStub)),
      matching: find.byWidgetPredicate((widget) => widget is TranscriptLiveSparkle || widget is Icon),
    );
    expect(tester.widget(glyphOf("Running · step 4")), isA<TranscriptLiveSparkle>());
    expect(tester.widget<Icon>(glyphOf("Ended with an error")).icon, TablerSolid.alert_circle);
    expect(tester.widget<Icon>(glyphOf("3 steps")).icon, TablerRegular.chevron_right);
    expect(find.bySemanticsLabel("Running · step 4"), findsOneWidget);
    semantics.dispose();
  });
}
