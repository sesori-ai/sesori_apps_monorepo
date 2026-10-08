import "package:clock/clock.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/compaction_part_widget.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_elapsed_time.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_latest_words.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_token_count_formatter.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

const _shortSummary = "## Carried forward\n\n- Keep the relay contract unchanged\n- Retry with a capped backoff";

/// Long enough to be worth deferring past the modal's entry transition.
final _longSummary =
    "$_shortSummary\n${List.filled(100, "- Another carried-forward decision and its reasoning").join("\n")}";

const _running = CompactionState.running(summary: null);

CompactionState _compacted({required String? summary, int? freedTokens, CompactionTrigger? trigger}) =>
    CompactionState.completed(summary: summary, freedTokens: freedTokens, trigger: trigger);

const _failed = CompactionState.failed(reason: CompactionFailureReason.alreadyCompacted);

Widget _app({
  required PregoInteractionMode mode,
  required CompactionState state,
  required int? sinceMs,
  required String? streamingText,
}) {
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
        sessionRepository: () => throw UnimplementedError("Prompt search is not under test"),
        canShareImages: false,
        openExternalLink: ({required url, required mode}) async => false,
        openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
        openHarnessSettings: () {},
        openBridgeSettings: () {},
        child: Scaffold(
          body: Column(
            children: [CompactionPartWidget(state: state, sinceMs: sinceMs, streamingText: streamingText)],
          ),
        ),
      ),
    ),
  );
}

/// The row under pointer, with no start time and nothing buffered.
Widget _row({required CompactionState state, String? streamingText}) =>
    _app(mode: PregoInteractionMode.pointer, state: state, sinceMs: null, streamingText: streamingText);

void _reduceMotion({required WidgetTester tester}) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

double _height({required WidgetTester tester}) => tester.getSize(find.byType(CompactionPartWidget)).height;

bool _tappable({required WidgetTester tester}) => tester.widget<TextButton>(find.byType(TextButton)).onPressed != null;

void main() {
  for (final mode in PregoInteractionMode.values) {
    testWidgets("the ${mode.name} modal opens behind a spinner, then shows the summary", (tester) async {
      await tester.pumpWidget(
        _app(
          mode: mode,
          state: _compacted(summary: _longSummary),
          sinceMs: null,
          streamingText: null,
        ),
      );

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
    _reduceMotion(tester: tester);
    await tester.pumpWidget(_row(state: _compacted(summary: _longSummary)));

    await tester.tap(find.text("Context compacted"));
    await tester.pump();

    expect(find.byType(PregoActivityIndicator), findsNothing);
    expect(find.textContaining("Keep the relay contract unchanged", findRichText: true), findsOneWidget);
  });

  testWidgets("a short summary shows at once, without a spinner", (tester) async {
    await tester.pumpWidget(_row(state: _compacted(summary: _shortSummary)));

    await tester.tap(find.text("Context compacted"));
    await tester.pump();

    expect(find.byType(PregoActivityIndicator), findsNothing);
    expect(find.textContaining("Keep the relay contract unchanged", findRichText: true), findsOneWidget);
  });

  testWidgets("only a compacted row with a summary opens it", (tester) async {
    for (final state in [const CompactionState.running(summary: _shortSummary), _compacted(summary: null), _failed]) {
      await tester.pumpWidget(_row(state: state));
      expect(_tappable(tester: tester), isFalse);
    }
    await tester.pumpWidget(_row(state: _compacted(summary: _shortSummary)));
    expect(_tappable(tester: tester), isTrue);
  });

  group("running", () {
    testWidgets("ticks the time since the compaction started, read once", (tester) async {
      await withClock(Clock(() => tester.binding.clock.now()), () async {
        final semantics = tester.ensureSemantics();
        final nowMs = tester.binding.clock.now().millisecondsSinceEpoch;
        await tester.pumpWidget(
          _app(mode: PregoInteractionMode.pointer, state: _running, sinceMs: nowMs - 101000, streamingText: null),
        );

        expect(find.byType(TranscriptLiveSparkle), findsOneWidget);
        expect(find.byType(PregoShimmer), findsOneWidget);
        expect(find.text("1m 41s"), findsOneWidget);
        expect(find.bySemanticsLabel("Compacting context · 1m 41s"), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text("1m 42s"), findsOneWidget);
        // Screen readers keep the time of the last build instead of every second.
        expect(find.bySemanticsLabel("Compacting context · 1m 41s"), findsOneWidget);
        semantics.dispose();
      });
    });

    testWidgets("shows no time when the harness reports none", (tester) async {
      await tester.pumpWidget(_row(state: _running));

      expect(find.text("Compacting context"), findsOneWidget);
      expect(find.byType(TranscriptElapsedTime), findsNothing);
    });

    testWidgets("shows the newest streamed words after the label, else the summary so far", (tester) async {
      await tester.pumpWidget(_row(state: _running));
      final oneLine = _height(tester: tester);
      expect(find.byType(TranscriptLatestWords), findsNothing);

      await tester.pumpWidget(_row(state: _running, streamingText: "Carried forward: the relay"));
      // The words fade in on the label's line, so the row never grows.
      await tester.pump(const Duration(milliseconds: 100));
      expect(_height(tester: tester), oneLine);
      await tester.pump(const Duration(milliseconds: 200));
      final words = find.text("Carried forward: the relay");
      expect(words, findsOneWidget);
      expect(_height(tester: tester), oneLine);
      final label = find.text("Compacting context");
      expect(tester.getCenter(words).dy, tester.getCenter(label).dy);
      expect(tester.getTopLeft(words).dx, greaterThan(tester.getTopRight(label).dx));

      await tester.pumpWidget(_row(state: const CompactionState.running(summary: "Carried forward")));
      expect(find.text("Carried forward"), findsOneWidget);
    });

    testWidgets("the newest words keep their place while the timer before them grows", (tester) async {
      await withClock(Clock(() => tester.binding.clock.now()), () async {
        const text = "Carried forward";
        final nowMs = tester.binding.clock.now().millisecondsSinceEpoch;
        Future<Offset> wordsEnd({required int? sinceMs}) async {
          await tester.pumpWidget(
            _app(mode: PregoInteractionMode.pointer, state: _running, sinceMs: sinceMs, streamingText: text),
          );
          await tester.pump(const Duration(milliseconds: 300));
          return tester.getTopRight(find.text(text));
        }

        final withoutTimer = await wordsEnd(sinceMs: null);
        expect(await wordsEnd(sinceMs: nowMs - 101000), withoutTimer);
      });
    });
  });

  group("settle", () {
    testWidgets("settles in place: the icon cross-fades and the height holds", (tester) async {
      await tester.pumpWidget(_row(state: _running));
      final height = _height(tester: tester);
      final switcher = tester.state(find.byType(AnimatedSwitcher).first);

      await tester.pumpWidget(
        _row(state: _compacted(summary: null, freedTokens: 142000, trigger: CompactionTrigger.auto)),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // The same row, mid cross-fade, at the same height.
      expect(tester.state(find.byType(AnimatedSwitcher).first), same(switcher));
      expect(find.byType(TranscriptLiveSparkle), findsOneWidget);
      expect(find.byIcon(TablerRegular.fold), findsOneWidget);
      expect(_height(tester: tester), height);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(TranscriptLiveSparkle), findsNothing);
      expect(find.byType(PregoShimmer), findsNothing);
      expect(find.text("Context compacted · freed 142k tokens · auto"), findsOneWidget);
      expect(_height(tester: tester), height);
    });

    testWidgets("the streamed words fade out as the row settles, at the same height", (tester) async {
      await tester.pumpWidget(_row(state: _running));
      final oneLine = _height(tester: tester);
      await tester.pumpWidget(_row(state: _running, streamingText: "Carried forward"));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(_row(state: _failed));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TranscriptLatestWords), findsOneWidget);
      expect(_height(tester: tester), oneLine);

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(TranscriptLatestWords), findsNothing);
      expect(_height(tester: tester), oneLine);
    });

    testWidgets("under reduced motion the row settles at once", (tester) async {
      _reduceMotion(tester: tester);
      await tester.pumpWidget(_row(state: _running));
      final oneLine = _height(tester: tester);
      await tester.pumpWidget(_row(state: _running, streamingText: "Carried forward"));
      expect(find.byType(TranscriptLatestWords), findsOneWidget);
      expect(_height(tester: tester), oneLine);

      await tester.pumpWidget(_row(state: _compacted(summary: null)));

      expect(find.byType(TranscriptLiveSparkle), findsNothing);
      expect(find.byIcon(TablerRegular.fold), findsOneWidget);
      expect(find.byType(TranscriptLatestWords), findsNothing);
      expect(_height(tester: tester), oneLine);
    });
  });

  group("details", () {
    testWidgets("names freed tokens and only an automatic trigger", (tester) async {
      await tester.pumpWidget(
        _row(state: _compacted(summary: null, freedTokens: 1200000, trigger: CompactionTrigger.manual)),
      );
      expect(find.text("Context compacted · freed 1.2M tokens"), findsOneWidget);

      await tester.pumpWidget(_row(state: _compacted(summary: null, trigger: CompactionTrigger.auto)));
      expect(find.text("Context compacted · auto"), findsOneWidget);

      await tester.pumpWidget(_row(state: _compacted(summary: null)));
      expect(find.text("Context compacted"), findsOneWidget);
    });

    testWidgets("a failure is a quiet note that names a known reason", (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_row(state: _failed));

      expect(find.text("Compaction failed · already compacted"), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(TablerRegular.alert_circle));
      expect(icon.color, PregoDesignSystem.light.colors.textSecondary);
      expect(find.bySemanticsLabel("Compaction failed · already compacted"), findsOneWidget);
      semantics.dispose();

      for (final (reason, text) in [
        (CompactionFailureReason.nothingToCompact, "Compaction failed · nothing to compact yet"),
        (CompactionFailureReason.cancelled, "Compaction failed · stopped"),
        (CompactionFailureReason.turnEnded, "Compaction failed · the turn ended first"),
        (null, "Compaction failed"),
      ]) {
        await tester.pumpWidget(_row(state: CompactionState.failed(reason: reason)));
        expect(find.text(text), findsOneWidget);
      }
    });
  });

  test("TranscriptTokenCountFormatter rounds to a short count", () {
    const cases = {
      0: "0",
      940: "940",
      1000: "1k",
      1240: "1.2k",
      9949: "9.9k",
      9950: "10k",
      142000: "142k",
      999499: "999k",
      999500: "1M",
      1200000: "1.2M",
      23000000: "23M",
    };
    for (final MapEntry(key: tokens, value: expected) in cases.entries) {
      expect(TranscriptTokenCountFormatter.format(tokens: tokens), expected, reason: "$tokens");
    }
  });
}
