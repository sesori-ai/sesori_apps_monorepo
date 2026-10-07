import "dart:async";

import "package:flutter/rendering.dart" show RenderParagraph;
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_prompts/prompt_search.dart";
import "package:sesori_app_ui/src/features/session_prompts/session_prompts_view.dart";
import "package:sesori_app_ui/src/features/session_prompts/widgets/prompt_day_header.dart";
import "package:sesori_app_ui/src/features/session_prompts/widgets/prompt_spine_row.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);
final _yesterday = DateTime(_today.year, _today.month, _today.day - 1);

TranscriptPromptEntry _opener({required String id, required DateTime? day}) => TranscriptPromptOpener(
  messageId: id,
  text: "Prompt $id",
  source: TranscriptPromptLoaded(fullText: "Prompt $id"),
  createdAt: day?.add(const Duration(hours: 9)).millisecondsSinceEpoch,
  dayKey: day,
  number: null,
);

TranscriptPromptEntry _followUp({required String id, required String openerId, required DateTime? day}) =>
    TranscriptPromptFollowUp(
      messageId: id,
      text: "Prompt $id",
      source: TranscriptPromptLoaded(fullText: "Prompt $id"),
      createdAt: day?.add(const Duration(hours: 10)).millisecondsSinceEpoch,
      dayKey: day,
      number: null,
      openerMessageId: openerId,
    );

/// [count] prompts over yesterday and today, oldest first.
List<TranscriptPromptEntry> _manyPrompts({required int count}) => [
  for (var index = 0; index < count; index++) _opener(id: "p$index", day: index < count / 2 ? _yesterday : _today),
];

/// Prompts p[from]..p[to - 1] from today, each saying on its second line,
/// past the one-line cut, whether its index is even or odd.
List<TranscriptPromptEntry> _parityPrompts({required int from, required int to}) => [
  for (var index = from; index < to; index++)
    TranscriptPromptOpener(
      messageId: "p$index",
      text: "Prompt p$index",
      source: TranscriptPromptLoaded(fullText: "Prompt p$index\nsits on an ${index.isEven ? "even" : "odd"} row"),
      createdAt: _today.add(Duration(minutes: index)).millisecondsSinceEpoch,
      dayKey: _today,
      number: null,
    ),
];

const _headerHeight = 52.0;
Finder _row(String id) => find.byKey(ValueKey(id));
double _topOf(WidgetTester tester, String id) => tester.getTopLeft(_row(id)).dy;
Color? _tintOf(WidgetTester tester, String id) =>
    tester.widget<Material>(find.descendant(of: _row(id), matching: find.byType(Material)).first).color;

Future<({List<String> taps, List<String> closes})> _pump(
  WidgetTester tester, {
  required List<TranscriptPromptEntry> entries,
  required String? anchor,
  VoidCallback? onLoadEarlier,
  bool isLoadEarlierBusy = false,
  bool autofocusSearch = false,
  bool isIndexed = false,
  Future<LoadThroughOutcome> Function({required String messageId, required int seq})? onLoadThrough,
}) async {
  final taps = <String>[];
  final closes = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SessionPromptsView(
        prompts: TranscriptPromptList(entries: entries, isIndexed: isIndexed),
        anchorMessageId: anchor,
        maxWidth: null,
        onLoadEarlier: onLoadEarlier,
        isLoadEarlierBusy: isLoadEarlierBusy,
        autofocusSearch: autofocusSearch,
        onPromptTap: ({required messageId}) => taps.add(messageId),
        onLoadThrough: onLoadThrough ?? ({required messageId, required seq}) async => const LoadThroughLoaded(),
        onClose: () => closes.add("close"),
      ),
    ),
  );
  return (taps: taps, closes: closes);
}

void main() {
  final dayHeaderExtent = promptDayHeaderExtent(textScaler: TextScaler.noScaling);

  testWidgets("lists prompts in transcript order, each follow-up indented below its opener", (tester) async {
    await _pump(
      tester,
      entries: [
        _opener(id: "a", day: _today),
        _followUp(id: "a1", openerId: "a", day: _today),
        _opener(id: "b", day: _today),
      ],
      anchor: null,
    );

    expect(_topOf(tester, "a"), lessThan(_topOf(tester, "a1")));
    expect(_topOf(tester, "a1"), lessThan(_topOf(tester, "b")));
    final [aX, a1X, bX] = [
      for (final id in ["a", "a1", "b"]) tester.getTopLeft(find.text("Prompt $id")).dx,
    ];
    expect(a1X, greaterThan(aX));
    expect(bX, aX);
    expect(find.text("3 prompts loaded"), findsOneWidget);
  });

  testWidgets("heads undated prompts with No date above the days, oldest day first", (tester) async {
    await _pump(
      tester,
      entries: [
        _opener(id: "undated", day: null),
        _opener(id: "old", day: _yesterday),
        _followUp(id: "old1", openerId: "old", day: _yesterday),
        _opener(id: "new", day: _today),
      ],
      anchor: null,
    );

    final headers = ["No date", "Yesterday", "Today"].map((label) => tester.getTopLeft(find.text(label)).dy).toList();
    expect(headers, orderedEquals([...headers]..sort()));
    // Under its day's heading a row shows the time alone, also on a past day.
    final context = tester.element(_row("new"));
    final nineToday = _today.add(const Duration(hours: 9)).millisecondsSinceEpoch;
    final nineYesterday = _yesterday.add(const Duration(hours: 9)).millisecondsSinceEpoch;
    expect(find.descendant(of: _row("new"), matching: find.text(context.formatTimeOfDay(nineToday))), findsOneWidget);
    expect(
      find.descendant(of: _row("old"), matching: find.text(context.formatTimeOfDay(nineYesterday))),
      findsOneWidget,
    );
    // An undated row in a timed list leaves its time cell empty.
    expect(find.descendant(of: _row("undated"), matching: find.byType(Text)), findsOneWidget);
  });

  testWidgets("a session nothing timed shows no day headers and no times", (tester) async {
    await _pump(
      tester,
      entries: [
        _opener(id: "a", day: null),
        _opener(id: "b", day: null),
      ],
      anchor: null,
    );

    expect(find.text("No date"), findsNothing);
    expect(_topOf(tester, "a"), _headerHeight);
    expect(find.descendant(of: _row("b"), matching: find.byType(Text)), findsOneWidget);
    expect(find.text("2 prompts loaded"), findsOneWidget);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets("opens on the anchored prompt, tinted for as long as it is open (reduce motion: $reduceMotion)", (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(reduceMotion: reduceMotion);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pump(tester, entries: _manyPrompts(count: 80), anchor: "p20");

      expect(_topOf(tester, "p20"), _headerHeight + dayHeaderExtent, reason: "just below its day's heading");
      final tint = _tintOf(tester, "p20");
      expect(tint, isNot(Colors.transparent));
      expect(_tintOf(tester, "p21"), Colors.transparent);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(_row("p20"), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
      await tester.pumpAndSettle();
      expect(_tintOf(tester, "p20"), tint);
    });
  }

  testWidgets("an unknown anchor opens at the newest end with nothing tinted", (tester) async {
    await _pump(tester, entries: _manyPrompts(count: 80), anchor: "gone");

    expect(_row("p79"), findsOneWidget);
    expect(find.text("80 prompts loaded"), findsOneWidget);
    for (final row in tester.widgetList<PromptSpineRow>(find.byType(PromptSpineRow))) {
      expect(row.highlighted, isFalse);
    }
  });

  testWidgets("an empty list says so", (tester) async {
    await _pump(tester, entries: const [], anchor: null);

    expect(find.text("No prompts in this session yet"), findsOneWidget);
  });

  testWidgets("a row is one labelled button that returns to its prompt; close closes", (tester) async {
    final semantics = tester.ensureSemantics();
    final calls = await _pump(
      tester,
      entries: [
        _opener(id: "a", day: null),
        _followUp(id: "a1", openerId: "a", day: null),
      ],
      anchor: null,
    );

    expect(
      tester.getSemantics(_row("a1")),
      matchesSemantics(
        label: "Follow-up: Prompt a1",
        hint: "Jump to this prompt",
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.text("1 prompt loaded"), findsNothing);
    await tester.tap(_row("a1"));
    await tester.tap(find.byTooltip("Close prompts"));
    expect(calls.taps, ["a1"]);
    expect(calls.closes, ["close"]);
    semantics.dispose();
  });

  group("search", () {
    testWidgets("filters as it is typed and clears, holding the reader's row in place throughout", (tester) async {
      // Enough rows below the reader that the filtered list still fills the
      // screen past it; a shorter one settles against its end instead.
      await _pump(tester, entries: _parityPrompts(from: 0, to: 60), anchor: "p30");
      final readerTop = _topOf(tester, "p30");

      await tester.enterText(find.byType(TextField), "EVEN");
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(_topOf(tester, "p30"), readerTop, reason: "the reader's row never moves while rows fold away");
      }
      await tester.pumpAndSettle();
      expect(_topOf(tester, "p30"), readerTop);
      expect(_row("p31"), findsNothing);
      expect(_row("p32"), findsOneWidget);
      expect(_tintOf(tester, "p30"), isNot(Colors.transparent), reason: "the anchored row keeps its tint");

      await tester.tap(find.byTooltip("Clear search"));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_topOf(tester, "p30"), readerTop);
      await tester.pumpAndSettle();
      expect(_topOf(tester, "p30"), readerTop);
      expect(_row("p31"), findsOneWidget);
    });

    testWidgets("holds the first row showing below the pinned day header, not one hidden beneath it", (tester) async {
      await _pump(tester, entries: _parityPrompts(from: 0, to: 80), anchor: null);
      final rowExtent = promptRowExtent(textScaler: TextScaler.noScaling);
      // p31 ends exactly where the pinned "Today" ends, so p32 is the first row
      // the reader sees.
      tester
          .state<ScrollableState>(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)))
          .position
          .jumpTo(32 * rowExtent);
      await tester.pump();
      final readerTop = _topOf(tester, "p32");
      expect(readerTop, _headerHeight + dayHeaderExtent);

      await tester.enterText(find.byType(TextField), "even");
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(_topOf(tester, "p32"), readerTop, reason: "the row in view stays put as the hidden p31 folds away");
      }
      await tester.pumpAndSettle();
      expect(_topOf(tester, "p32"), readerTop);
    });

    testWidgets("a search with no match, cleared, returns the reader to the row they were on", (tester) async {
      await _pump(tester, entries: _parityPrompts(from: 0, to: 60), anchor: "p30");
      final readerTop = _topOf(tester, "p30");

      await tester.enterText(find.byType(TextField), "nothing like it");
      await tester.pumpAndSettle();
      expect(find.byType(PromptSpineRow), findsNothing);

      await tester.tap(find.byTooltip("Clear search"));
      await tester.pumpAndSettle();
      expect(_topOf(tester, "p30"), readerTop);
    });

    testWidgets("a row still folding away keeps its excerpt when the query changes again", (tester) async {
      await _pump(tester, entries: _parityPrompts(from: 0, to: 4), anchor: null);
      await tester.enterText(find.byType(TextField), "o");
      await tester.pumpAndSettle();
      final p0Excerpt = find.descendant(
        of: _row("p0"),
        matching: find.text("Prompt p0 sits on an even row", findRichText: true),
      );
      expect(p0Excerpt, findsOneWidget);

      // Typed faster than the fold: p0 is still folding away from "od".
      await tester.enterText(find.byType(TextField), "od");
      await tester.pump(const Duration(milliseconds: 40));
      await tester.enterText(find.byType(TextField), "odd");
      await tester.pump(const Duration(milliseconds: 40));
      expect(p0Excerpt, findsOneWidget);
      await tester.pumpAndSettle();
      expect(_row("p0"), findsNothing);
    });

    testWidgets("at a large text size on a narrow phone the match stays on its line and the count fits", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        entries: [
          TranscriptPromptOpener(
            messageId: "wide",
            text: "Prompt wide",
            source: TranscriptPromptLoaded(fullText: "Prompt wide\n${"W" * 30} needle"),
            createdAt: null,
            dayKey: null,
            number: null,
          ),
        ],
        anchor: null,
      );

      await tester.enterText(find.byType(TextField), "needle");
      await tester.pumpAndSettle();
      final excerpt = tester.renderObject<RenderParagraph>(
        find.descendant(of: _row("wide"), matching: find.byType(RichText)).last,
      );
      final needle = excerpt.text.toPlainText().indexOf("needle");
      final boxes = excerpt.getBoxesForSelection(TextSelection(baseOffset: needle, extentOffset: needle + 6));
      expect(boxes, isNotEmpty);
      expect(boxes.last.right, lessThanOrEqualTo(excerpt.size.width), reason: "the whole match shows");

      final count = find.text("1 match in the prompts loaded so far");
      final countParagraph = tester.renderObject<RenderParagraph>(count);
      final countBox = tester.getSize(find.ancestor(of: count, matching: find.byType(SizedBox)).first);
      expect(
        countParagraph.getMinIntrinsicHeight(countParagraph.constraints.maxWidth) + PregoSpacing.xl * 2,
        lessThanOrEqualTo(countBox.height),
      );
    });

    test("an excerpt never cuts an emoji in half", () {
      // Both cut points fall on the second half of an emoji.
      final text = "${"😀" * 20}xneedley${"😀" * 50}";
      final match = RegExp("needle").firstMatch(text);
      expect(match, isNotNull);
      if (match == null) return;
      final excerpt = promptExcerpt(text: text, match: match);
      for (final part in [excerpt.before, excerpt.after]) {
        expect(part.runes.where((rune) => rune >= 0xD800 && rune <= 0xDFFF), isEmpty);
      }
    });

    testWidgets("a match past the one-line cut grows the row and highlights the match", (tester) async {
      await _pump(tester, entries: _parityPrompts(from: 0, to: 2), anchor: null);

      await tester.enterText(find.byType(TextField), "odd");
      await tester.pumpAndSettle();

      expect(_row("p0"), findsNothing);
      const scaler = TextScaler.noScaling;
      expect(
        tester.getSize(_row("p1")).height,
        promptRowExtent(textScaler: scaler) + promptExcerptExtent(textScaler: scaler),
      );
      final excerpt = tester.widget<RichText>(
        find.descendant(of: _row("p1"), matching: find.byType(RichText)).last,
      );
      expect(excerpt.text.toPlainText(), "Prompt p1 sits on an odd row");
      final highlighted = <String>[];
      excerpt.text.visitChildren((span) {
        if (span is TextSpan && span.style?.fontWeight == FontWeight.w600) highlighted.add(span.text ?? "");
        return true;
      });
      expect(highlighted, ["odd"]);
      expect(find.text("1 match in the prompts loaded so far"), findsOneWidget);
    });

    testWidgets("day headers keep only the days that still have rows", (tester) async {
      await _pump(
        tester,
        entries: [
          _opener(id: "old", day: _yesterday),
          _opener(id: "new", day: _today),
        ],
        anchor: null,
      );

      await tester.enterText(find.byType(TextField), "new");
      await tester.pumpAndSettle();
      expect(find.text("Yesterday"), findsNothing);
      expect(find.text("Today"), findsOneWidget);

      await tester.enterText(find.byType(TextField), "nothing like it");
      await tester.pumpAndSettle();
      expect(find.text("Today"), findsNothing);
      expect(find.text("No matches in the prompts loaded so far"), findsOneWidget);
    });

    testWidgets("Load earlier prompts heads the list, calls the loader and waits while it runs", (tester) async {
      var loads = 0;
      final entries = _parityPrompts(from: 0, to: 3);
      await _pump(tester, entries: entries, anchor: null, onLoadEarlier: () => loads++);

      final control = find.byKey(const Key("session-prompts-load-earlier"));
      expect(tester.getTopLeft(control).dy, lessThan(_topOf(tester, "p0")));
      await tester.tap(control);
      expect(loads, 1);

      await _pump(tester, entries: entries, anchor: null, onLoadEarlier: () => loads++, isLoadEarlierBusy: true);
      expect(tester.widget<TextButton>(control).onPressed, isNull);
    });

    /// Expects the control's label to wrap and every line of it to show above
    /// the first row.
    void expectWholeWrappedLabel(WidgetTester tester) {
      final control = find.byKey(const Key("session-prompts-load-earlier"));
      final label = find.descendant(of: control, matching: find.byType(RichText));
      final paragraph = tester.renderObject<RenderParagraph>(label);
      final lineTops = paragraph
          .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: paragraph.text.toPlainText().length))
          .map((box) => box.top)
          .toSet();
      expect(lineTops.length, greaterThan(1), reason: "the label wraps");
      expect(
        paragraph.getMinIntrinsicHeight(paragraph.size.width),
        lessThanOrEqualTo(paragraph.size.height),
        reason: "every line of the label is laid out",
      );
      final sliver = tester.getRect(find.ancestor(of: control, matching: find.byType(SizedBox)).first);
      final labelRect = tester.getRect(label);
      expect(labelRect.top, greaterThanOrEqualTo(sliver.top));
      expect(labelRect.bottom, lessThanOrEqualTo(sliver.bottom));
      expect(_topOf(tester, "p0"), greaterThanOrEqualTo(sliver.bottom));
    }

    testWidgets("at a large text size on a narrow phone Load earlier prompts wraps and shows whole", (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, entries: _parityPrompts(from: 0, to: 3), anchor: null, onLoadEarlier: () {});

      expectWholeWrappedLabel(tester);
    });

    testWidgets("Load earlier prompts wrapped by the platform's letter spacing shows whole", (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.letterSpacingOverrideTestValue = 25;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await _pump(tester, entries: _parityPrompts(from: 0, to: 3), anchor: null, onLoadEarlier: () {});

      expectWholeWrappedLabel(tester);
    });

    testWidgets("earlier prompts join the search below the control and leave the reader's row still", (tester) async {
      await _pump(tester, entries: _parityPrompts(from: 20, to: 60), anchor: "p40", onLoadEarlier: () {});
      await tester.enterText(find.byType(TextField), "even");
      await tester.pumpAndSettle();
      final readerTop = _topOf(tester, "p40");

      await _pump(tester, entries: _parityPrompts(from: 0, to: 60), anchor: "p40", onLoadEarlier: () {});
      expect(_topOf(tester, "p40"), readerTop);

      // The load that reaches the session's start also takes the control away.
      await _pump(tester, entries: _parityPrompts(from: 0, to: 60), anchor: "p40", onLoadEarlier: null);
      expect(_topOf(tester, "p40"), readerTop);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(_row("p0"), findsOneWidget);
      expect(_row("p1"), findsNothing);
    });

    testWidgets("Escape closes the screen, from the search field too", (tester) async {
      final phone = await _pump(tester, entries: _parityPrompts(from: 0, to: 3), anchor: null);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(phone.closes, ["close"]);

      await tester.pumpWidget(const SizedBox());
      final desktop = await _pump(tester, entries: _parityPrompts(from: 0, to: 3), anchor: null, autofocusSearch: true);
      await tester.pump();
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(desktop.closes, ["close"]);
    });

    testWidgets("Escape still closes after a click outside the search field takes its focus", (tester) async {
      final calls = await _pump(tester, entries: _parityPrompts(from: 0, to: 3), anchor: null, autofocusSearch: true);
      await tester.pump();
      await tester.enterText(find.byType(TextField), "even");
      await tester.pumpAndSettle();

      await tester.tap(find.text("2 matches in the prompts loaded so far"));
      await tester.pump();
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(calls.closes, ["close"]);
    });
  });

  group("prompts the transcript has not loaded", () {
    TranscriptPromptEntry unloaded({required String id, required int seq}) => TranscriptPromptOpener(
      messageId: id,
      text: "Prompt $id",
      source: TranscriptPromptUnloaded(seq: seq, preview: "Prompt $id"),
      createdAt: null,
      dayKey: null,
      number: null,
    );

    testWidgets("a list of every prompt counts them all", (tester) async {
      await _pump(
        tester,
        entries: [
          unloaded(id: "old", seq: 1),
          _opener(id: "new", day: null),
        ],
        anchor: null,
        isIndexed: true,
      );

      expect(find.text("2 prompts"), findsOneWidget);
    });

    testWidgets("a tap keeps the screen up, shows a spinner only after a moment, then moves there", (tester) async {
      final load = Completer<LoadThroughOutcome>();
      final asked = <(String, int)>[];
      final calls = await _pump(
        tester,
        entries: [unloaded(id: "old", seq: 7)],
        anchor: null,
        isIndexed: true,
        onLoadThrough: ({required messageId, required seq}) {
          asked.add((messageId, seq));
          return load.future;
        },
      );

      await tester.tap(_row("old"));
      await tester.pump(const Duration(milliseconds: 100));
      expect(asked, [("old", 7)]);
      expect(find.byType(PregoActivityIndicator), findsNothing, reason: "a quick load shows no spinner");
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(PregoActivityIndicator), findsOneWidget);
      expect(calls.taps, isEmpty);

      load.complete(const LoadThroughLoaded());
      await tester.pump();
      expect(calls.taps, ["old"]);
      expect(find.byType(PregoActivityIndicator), findsNothing);
    });

    testWidgets("a second tap replaces the first, and a load that cannot land says why", (tester) async {
      final first = Completer<LoadThroughOutcome>();
      final loads = {"a": first.future, "b": Future<LoadThroughOutcome>.value(const LoadThroughUnsupported())};
      final calls = await _pump(
        tester,
        entries: [
          unloaded(id: "a", seq: 1),
          unloaded(id: "b", seq: 2),
        ],
        anchor: null,
        isIndexed: true,
        onLoadThrough: ({required messageId, required seq}) => loads[messageId] ?? first.future,
      );

      await tester.tap(_row("a"));
      await tester.pump();
      await tester.tap(_row("b"));
      await tester.pump();
      first.complete(const LoadThroughLoaded());
      await tester.pumpAndSettle();

      expect(calls.taps, isEmpty, reason: "the first tap's target was replaced");
      expect(find.text("Update the bridge to open earlier prompts"), findsOneWidget);
    });

    testWidgets("tapping a, b, then a again ignores the first load of a", (tester) async {
      final loads = <String, List<Completer<LoadThroughOutcome>>>{"a": [], "b": []};
      final calls = await _pump(
        tester,
        entries: [
          unloaded(id: "a", seq: 1),
          unloaded(id: "b", seq: 2),
        ],
        anchor: null,
        isIndexed: true,
        onLoadThrough: ({required messageId, required seq}) {
          final load = Completer<LoadThroughOutcome>();
          loads[messageId]?.add(load);
          return load.future;
        },
      );

      await tester.tap(_row("a"));
      await tester.pump();
      await tester.tap(_row("b"));
      await tester.pump();
      await tester.tap(_row("a"));
      await tester.pump();
      loads["a"]?.first.complete(const LoadThroughLoaded());
      await tester.pump();
      expect(calls.taps, isEmpty, reason: "the first load of a belongs to a replaced tap");

      loads["a"]?.last.complete(const LoadThroughLoaded());
      await tester.pump();
      expect(calls.taps, ["a"]);
    });

    testWidgets("another tap on the prompt already loading sends no second load", (tester) async {
      final load = Completer<LoadThroughOutcome>();
      var loads = 0;
      final calls = await _pump(
        tester,
        entries: [unloaded(id: "old", seq: 7)],
        anchor: null,
        isIndexed: true,
        onLoadThrough: ({required messageId, required seq}) {
          loads++;
          return load.future;
        },
      );

      await tester.tap(_row("old"));
      await tester.pump();
      await tester.tap(_row("old"));
      await tester.pump();
      load.complete(const LoadThroughLoaded());
      await tester.pump();

      expect(loads, 1);
      expect(calls.taps, ["old"]);
    });

    testWidgets("a row tells screen readers it is loading, and a load a refresh dropped asks for another tap", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final load = Completer<LoadThroughOutcome>();
      await _pump(
        tester,
        entries: [unloaded(id: "old", seq: 7)],
        anchor: null,
        isIndexed: true,
        onLoadThrough: ({required messageId, required seq}) => load.future,
      );

      await tester.tap(_row("old"));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.getSemantics(find.byType(PromptSpineRow)),
        matchesSemantics(
          value: "Loading",
          isLiveRegion: true,
          isButton: true,
          hasTapAction: true,
          label: "Prompt old",
          hint: "Jump to this prompt",
        ),
      );

      load.complete(const LoadThroughSuperseded());
      await tester.pumpAndSettle();
      expect(find.text("The session just refreshed. Tap the prompt again."), findsOneWidget);
      semantics.dispose();
    });

    testWidgets("searching a list of every prompt counts matches without a loaded range", (tester) async {
      await _pump(
        tester,
        entries: [
          unloaded(id: "old", seq: 1),
          _opener(id: "new", day: null),
        ],
        anchor: null,
        isIndexed: true,
      );

      await tester.enterText(find.byType(TextField), "old");
      await tester.pumpAndSettle();

      expect(find.text("1 match"), findsOneWidget);
    });
  });
}
