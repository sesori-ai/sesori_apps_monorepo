import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
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
  fullText: "Prompt $id",
  createdAt: day?.add(const Duration(hours: 9)).millisecondsSinceEpoch,
  dayKey: day,
  number: null,
);

TranscriptPromptEntry _followUp({required String id, required String openerId, required DateTime? day}) =>
    TranscriptPromptFollowUp(
      messageId: id,
      text: "Prompt $id",
      fullText: "Prompt $id",
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
      fullText: "Prompt p$index\nsits on an ${index.isEven ? "even" : "odd"} row",
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
  bool isLoadingEarlier = false,
  bool autofocusSearch = false,
}) async {
  final taps = <String>[];
  final closes = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SessionPromptsView(
        prompts: TranscriptPromptList(entries: entries),
        anchorMessageId: anchor,
        maxWidth: null,
        onLoadEarlier: onLoadEarlier,
        isLoadingEarlier: isLoadingEarlier,
        autofocusSearch: autofocusSearch,
        onPromptTap: ({required messageId}) => taps.add(messageId),
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

      await _pump(tester, entries: entries, anchor: null, onLoadEarlier: () => loads++, isLoadingEarlier: true);
      expect(tester.widget<TextButton>(control).onPressed, isNull);
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
  });
}
