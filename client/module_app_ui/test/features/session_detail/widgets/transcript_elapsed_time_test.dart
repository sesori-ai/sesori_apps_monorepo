import "package:clock/clock.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_duration_formatter.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_elapsed_time.dart";
import "package:theme_prego/module_prego.dart";

/// Runs [callback] with `clock` reading the test's fake time.
void _clockTestWidgets(String description, WidgetTesterCallback callback) => testWidgets(
  description,
  (tester) => withClock(Clock(() => tester.binding.clock.now()), () => callback(tester)),
);

Widget _harness({required Widget child}) => MaterialApp(
  theme: ThemeData(extensions: [PregoDesignSystem.light]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

int _nowMs({required WidgetTester tester}) => tester.binding.clock.now().millisecondsSinceEpoch;

void main() {
  group("TranscriptDurationFormatter", () {
    final cases = <Duration, String>{
      Duration.zero: "0s",
      const Duration(seconds: 59): "59s",
      const Duration(seconds: 60): "1m 00s",
      const Duration(seconds: 62): "1m 02s",
      const Duration(seconds: 3599): "59m 59s",
      const Duration(seconds: 3600): "1h 00m 00s",
      const Duration(seconds: 3905): "1h 05m 05s",
      const Duration(seconds: 3912): "1h 05m 12s",
      const Duration(seconds: -5): "0s",
    };
    for (final MapEntry(key: duration, value: expected) in cases.entries) {
      test("$duration reads $expected", () {
        expect(TranscriptDurationFormatter.format(loc: AppLocalizationsEn(), duration: duration), expected);
      });
    }
  });

  group("TranscriptElapsedTime", () {
    _clockTestWidgets("ticks on each whole elapsed second", (tester) async {
      await tester.pumpWidget(
        _harness(
          child: TranscriptElapsedTime(sinceMs: _nowMs(tester: tester) - 1400, style: null),
        ),
      );
      expect(find.text("1s"), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 599));
      expect(find.text("1s"), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text("2s"), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 999));
      expect(find.text("2s"), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text("3s"), findsOneWidget);
      await tester.pump(const Duration(seconds: 58));
      expect(find.text("1m 01s"), findsOneWidget);

      // Disposal cancels the timer; a pending one would fail the test.
      await tester.pumpWidget(_harness(child: const SizedBox()));
    });

    _clockTestWidgets("holds at 0s while the start is ahead of the device clock", (tester) async {
      await tester.pumpWidget(
        _harness(
          child: TranscriptElapsedTime(sinceMs: _nowMs(tester: tester) + 1500, style: null),
        ),
      );
      expect(find.text("0s"), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text("0s"), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text("1s"), findsOneWidget);

      await tester.pumpWidget(_harness(child: const SizedBox()));
    });
  });

  group("TranscriptWorkingRow", () {
    _clockTestWidgets("appends the time since the prompt and reads it once to screen readers", (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          child: TranscriptWorkingRow(sinceMs: _nowMs(tester: tester) - 103000),
        ),
      );
      expect(find.text("Working… · "), findsOneWidget);
      expect(find.text("1m 43s"), findsOneWidget);
      expect(find.bySemanticsLabel("Working… · 1m 43s"), findsOneWidget);
      expect(find.bySemanticsLabel("1m 43s"), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text("1m 44s"), findsOneWidget);

      await tester.pumpWidget(_harness(child: const SizedBox()));
      semantics.dispose();
    });

    _clockTestWidgets("reads plain Working… when the prompt time is unknown", (tester) async {
      await tester.pumpWidget(_harness(child: const TranscriptWorkingRow(sinceMs: null)));

      expect(find.text("Working…"), findsOneWidget);
      expect(find.byType(TranscriptElapsedTime), findsNothing);

      await tester.pumpWidget(_harness(child: const SizedBox()));
    });
  });
}
