import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

const _toggle = ValueKey("shellTool.toggle");
const _viewport = ValueKey("shellTool.viewport");

/// The open details around the terminal viewport.
final _panel = find.ancestor(
  of: find.byKey(_viewport),
  matching: find.byWidgetPredicate((widget) => widget is Container && widget.decoration != null),
);

/// The command row plus whatever part of the panel is showing.
double _shellHeight(WidgetTester tester) =>
    tester.getSize(find.ancestor(of: find.byKey(_toggle), matching: find.byType(Column)).first).height;

MessagePartTool _part({
  required ToolStatus status,
  required String? command,
  required String? output,
  required String? error,
}) => MessagePartTool(
  id: "tool-1",
  sessionID: "session-1",
  messageID: "message-1",
  tool: "Any normalized tool name",
  state: ToolState(
    status: status,
    title: "A tool title",
    shellCommand: command,
    output: output,
    error: error,
  ),
);

Widget _app({
  required MessagePartTool part,
  Brightness brightness = Brightness.light,
  double width = 370,
  double textScale = 1,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: buildPregoThemeData(brightness: brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(top: 62, bottom: 34),
        disableAnimations: disableAnimations,
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: ToolPartWidget(part: part),
        ),
      ),
    ),
  ),
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets("${brightness.name} shell disclosure uses Figma tokens and a bounded viewport", (tester) async {
      await tester.pumpWidget(
        _app(
          brightness: brightness,
          part: _part(status: ToolStatus.completed, command: "git status --short", output: " M file.dart", error: null),
        ),
      );
      expect(find.text(r"Ran $ git status --short"), findsOneWidget);
      expect(_panel, findsNothing);
      expect(tester.getSize(find.byKey(_toggle)).height, greaterThanOrEqualTo(44));
      await tester.tap(find.byKey(_toggle));
      await tester.pumpAndSettle();

      final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;
      final decoration = tester.widget<Container>(_panel).decoration! as BoxDecoration;
      // The same raised inset as code blocks and other tool output.
      expect(decoration.color, prego.colors.bgSurface4);
      expect(decoration.borderRadius, BorderRadius.circular(PregoRadius.xs));
      expect(decoration.border, isNull);
      // A short transcript keeps the panel short.
      expect(tester.getSize(find.byKey(_viewport)).height, lessThan(144));
      expect(find.text("Shell"), findsOneWidget);
      // A finished command says nothing more than what it ran.
      expect(find.text("Done"), findsNothing);
      expect(find.text("\$ git status --short\n\n M file.dart"), findsOneWidget);
      await tester.tap(find.byKey(_toggle));
      await tester.pumpAndSettle();
      expect(_panel, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (status, label) in [
    (ToolStatus.pending, "Pending"),
    (ToolStatus.running, "Running"),
    (ToolStatus.completed, "Ran"),
    (ToolStatus.error, "Failed"),
    (ToolStatus.cancelled, "Cancelled"),
    (ToolStatus.unknown, "Tool"),
  ]) {
    testWidgets("shell names the ${status.name} status in its line", (tester) async {
      await tester.pumpWidget(
        _app(
          part: _part(
            status: status,
            command: "make check",
            output: null,
            error: status == ToolStatus.error ? "Command exited with code 1" : null,
          ),
        ),
      );
      expect(find.text("$label \$ make check"), findsOneWidget);
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      if (status == ToolStatus.error) {
        expect(find.text("\$ make check\n\nCommand exited with code 1"), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("one copy takes the transcript as shown", (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "Clipboard.setData") copied = (call.arguments as Map)["text"] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    const command = "printf 'hello\\n'\nprintf 'world'";
    const output = "hello\nworld\n";
    await tester.pumpWidget(
      _app(
        part: _part(status: ToolStatus.completed, command: command, output: output, error: null),
      ),
    );
    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    expect(find.byTooltip("Copy"), findsOneWidget);
    await tester.tap(find.byTooltip("Copy"));
    await tester.pump();
    expect(copied, "\$ $command\n\n$output");
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("long command and output scroll on both axes without growing the transcript", (tester) async {
    final command = "printf '${'long-command-' * 60}'";
    final output = List.generate(50, (index) => "line $index").join("\n");
    await tester.pumpWidget(
      _app(
        part: _part(status: ToolStatus.completed, command: command, output: output, error: null),
      ),
    );
    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    final viewport = find.byKey(_viewport);
    final scrolls = tester.widgetList<SingleChildScrollView>(
      find.descendant(of: viewport, matching: find.byType(SingleChildScrollView)),
    );
    final horizontal = scrolls.singleWhere((scroll) => scroll.scrollDirection == Axis.horizontal).controller!;
    final vertical = scrolls.singleWhere((scroll) => scroll.scrollDirection == Axis.vertical).controller!;
    expect(horizontal.position.maxScrollExtent, greaterThan(0));
    expect(vertical.position.maxScrollExtent, greaterThan(0));
    for (final scrollbar in find.byType(RawScrollbar).evaluate()) {
      expect(MediaQuery.paddingOf(scrollbar), EdgeInsets.zero);
    }
    final panelHeight = tester.getSize(_panel).height;
    await tester.drag(viewport, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(horizontal.offset, greaterThan(0));
    await tester.drag(viewport, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(vertical.offset, greaterThan(0));
    expect(tester.getSize(_panel).height, panelHeight);
    expect(tester.getSize(viewport).height, 144);
    // A sideways swipe on the panel's title still scrolls the transcript.
    final before = horizontal.offset;
    await tester.drag(find.text("Shell"), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(horizontal.offset, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets("open shell updates with streamed output and terminal status", (tester) async {
    await tester.pumpWidget(
      _app(
        part: _part(status: ToolStatus.running, command: "make check", output: "Starting", error: null),
      ),
    );
    await tester.tap(find.byKey(_toggle));
    await tester.pump();
    await tester.pumpWidget(
      _app(
        part: _part(status: ToolStatus.completed, command: "make check", output: "All checks passed", error: null),
      ),
    );
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    expect(find.text("\$ make check\n\nAll checks passed"), findsOneWidget);
    expect(find.text(r"Ran $ make check"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Widget reversedTranscript({required double newerContent, required double composerInset}) => MaterialApp(
    theme: buildPregoThemeData(brightness: Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        key: const ValueKey("transcript"),
        height: 500,
        child: ListView(
          reverse: true,
          padding: EdgeInsets.only(bottom: composerInset),
          children: [
            SizedBox(height: newerContent),
            ToolPartWidget(
              part: _part(status: ToolStatus.completed, command: "pwd", output: "result", error: null),
            ),
            const SizedBox(height: 500),
          ],
        ),
      ),
    ),
  );

  testWidgets("a historical command keeps its header still while it opens and closes", (tester) async {
    await tester.pumpWidget(reversedTranscript(newerContent: 350, composerInset: 0));
    final before = tester.getRect(find.byKey(_toggle));

    await tester.tap(find.byKey(_toggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-animation too: the scroll moves with the panel, not after it.
    expect(tester.getRect(find.byKey(_toggle)), before);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_toggle)), before);
    final transcript = tester.getRect(find.byKey(const ValueKey("transcript")));
    expect(tester.getRect(_panel).bottom, lessThan(transcript.bottom));

    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_toggle)), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a short transcript grows the row into the space above it", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: ListView(
              reverse: true,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              children: [
                const SizedBox(height: 60),
                ToolPartWidget(
                  part: _part(status: ToolStatus.completed, command: "pwd", output: "result", error: null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final before = tester.getRect(find.byKey(_toggle));

    await tester.tap(find.byKey(_toggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // No overscroll mid-animation, which would bounce back.
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.pixels, 0);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_toggle)).top, lessThan(before.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets("the newest command opens upward, clear of the composer", (tester) async {
    // The transcript pads its bottom so the newest row clears the composer.
    await tester.pumpWidget(reversedTranscript(newerContent: 0, composerInset: 120));
    final before = tester.getRect(find.byKey(_toggle));

    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();

    final transcript = tester.getRect(find.byKey(const ValueKey("transcript")));
    expect(tester.getRect(find.byKey(_toggle)).top, lessThan(before.top));
    expect(tester.getRect(_panel).bottom, moreOrLessEquals(transcript.bottom - 120));
    expect(tester.takeException(), isNull);
  });

  testWidgets("shell details ease open and shut", (tester) async {
    await tester.pumpWidget(
      _app(
        part: _part(status: ToolStatus.completed, command: "pwd", output: "result", error: null),
      ),
    );
    double height() => _shellHeight(tester);
    final closed = height();
    await tester.tap(find.byKey(_toggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final opening = height();
    await tester.pumpAndSettle();
    final open = height();
    // Halfway through, a decelerating open has covered more than half.
    final halfway = (closed + open) / 2;
    expect(opening, allOf(greaterThan(halfway), lessThan(open)));

    await tester.tap(find.byKey(_toggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // The close decelerates too, so it has also covered more than half.
    expect(height(), allOf(greaterThan(closed), lessThan(halfway)));
    // The details stay on screen while they close, rather than leaving a
    // blank area to collapse.
    expect(_panel, findsOneWidget);
    await tester.pumpAndSettle();
    expect(height(), closed);
    expect(_panel, findsNothing);
  });

  // Android's "Remove animations" arrives through MediaQuery, iOS's "Reduce
  // Motion" only through the accessibility features.
  for (final (source, disableAnimations) in [("Remove animations", true), ("Reduce Motion", false)]) {
    testWidgets("$source opens shell details at once", (tester) async {
      if (!disableAnimations) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }
      await tester.pumpWidget(
        _app(
          disableAnimations: disableAnimations,
          part: _part(status: ToolStatus.completed, command: "pwd", output: "result", error: null),
        ),
      );
      double height() => _shellHeight(tester);
      final closed = height();
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      final open = height();
      expect(open, greaterThan(closed));
      await tester.pumpAndSettle();
      expect(height(), open);

      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      expect(height(), closed);
      expect(_panel, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("tool output eases open behind its row", (tester) async {
    await tester.pumpWidget(
      _app(
        part: _part(
          status: ToolStatus.completed,
          command: null,
          output: List.generate(20, (index) => "line $index").join("\n"),
          error: null,
        ),
      ),
    );
    double height() => _shellHeight(tester);
    final collapsed = height();
    expect(find.textContaining("line 0"), findsNothing);
    await tester.tap(find.byKey(_toggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final opening = height();
    await tester.pumpAndSettle();
    expect(opening, allOf(greaterThan(collapsed), lessThan(height())));
    expect(find.textContaining("line 0"), findsOneWidget);
    // Long output scrolls inside the bounded viewport; nothing says Show more.
    expect(tester.getSize(find.byKey(_viewport)).height, 144);
    expect(find.text("Show more"), findsNothing);
  });

  testWidgets("shell disclosure supports keyboard activation", (tester) async {
    await tester.pumpWidget(
      _app(
        part: _part(status: ToolStatus.completed, command: "pwd", output: null, error: null),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_panel, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_panel, findsNothing);
  });

  testWidgets("shell fits a narrow pane with enlarged text", (tester) async {
    await tester.pumpWidget(
      _app(
        width: 240,
        textScale: 2,
        part: _part(
          status: ToolStatus.cancelled,
          command: "a long command with arguments",
          output: "output",
          error: null,
        ),
      ),
    );
    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    expect(tester.getSize(_panel).width, 240);
    expect(tester.takeException(), isNull);
  });

  testWidgets("ordinary tools keep normalized titles without shell-name guessing", (tester) async {
    await tester.pumpWidget(
      _app(
        part: _part(status: ToolStatus.completed, command: null, output: "Old peer output", error: null),
      ),
    );
    expect(find.text("Any normalized tool name A tool title"), findsOneWidget);
    expect(find.byIcon(TablerRegular.tool), findsOneWidget);
    expect(find.text("Done"), findsNothing);
    expect(find.text("Old peer output"), findsNothing);

    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    expect(find.text("Old peer output"), findsOneWidget);
    expect(find.byType(PregoCopyIconButton), findsOneWidget);
  });

  testWidgets("a tool without details is a plain row", (tester) async {
    await tester.pumpWidget(_app(part: _part(status: ToolStatus.completed, command: null, output: null, error: null)));
    expect(find.byKey(_toggle), findsNothing);
    expect(find.text("Any normalized tool name A tool title"), findsOneWidget);
  });

  testWidgets("a failed tool keeps one signal and shows its error in the details", (tester) async {
    await tester.pumpWidget(
      _app(
        part: _part(status: ToolStatus.error, command: null, output: null, error: "File not found"),
      ),
    );
    expect(find.byIcon(TablerSolid.alert_circle), findsOneWidget);
    expect(find.text("Failed"), findsNothing);
    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    expect(find.text("File not found"), findsOneWidget);
  });

  for (final disableAnimations in [false, true]) {
    testWidgets("a running tool's label shimmers in place of a spinner (reduced motion: $disableAnimations)", (
      tester,
    ) async {
      for (final command in ["make check", null]) {
        await tester.pumpWidget(
          _app(
            part: _part(status: ToolStatus.running, command: command, output: null, error: null),
            disableAnimations: disableAnimations,
          ),
        );
        await tester.pump();
        expect(find.byType(PregoActivityIndicator), findsNothing);
        expect(find.byType(PregoShimmer), findsOneWidget);
        // Reduced motion keeps the label still.
        expect(
          find.descendant(of: find.byType(PregoShimmer), matching: find.byType(ShaderMask)),
          disableAnimations ? findsNothing : findsOneWidget,
        );
      }
    });
  }

  group("a summary part", () {
    const key = (messageId: "message-1", partId: "tool-1");
    const summary = MessagePartTool(
      id: "tool-1",
      sessionID: "session-1",
      messageID: "message-1",
      tool: "Any normalized tool name",
      state: ToolState.summary(status: ToolStatus.completed, title: null, shellCommand: "make check", attachments: []),
    );
    late _Cubit cubit;
    late StreamController<SessionDetailState> states;

    setUp(() {
      cubit = _Cubit();
      states = StreamController<SessionDetailState>();
      when(() => cubit.fetchToolOutput(messageId: "message-1", partId: "tool-1")).thenAnswer((_) async {});
    });
    tearDown(() => states.close());

    Widget transcript({required Map<ToolOutputKey, ToolOutputFetch> toolOutputs, required MessagePartTool part}) {
      whenListen(cubit, states.stream, initialState: _loaded(toolOutputs: toolOutputs));
      return MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SessionDetailCubit>.value(
          value: cubit,
          child: Scaffold(
            body: SizedBox(
              height: 500,
              child: ListView(
                reverse: true,
                children: [
                  const SizedBox(height: 350),
                  ToolPartWidget(part: part),
                  const SizedBox(height: 500),
                ],
              ),
            ),
          ),
        ),
      );
    }

    double spinnerOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: find.byKey(const ValueKey("toolOutput.spinner")), matching: find.byType(AnimatedOpacity)),
        )
        .opacity;

    testWidgets("fetches its output on opening and eases to it with the header still", (tester) async {
      await tester.pumpWidget(transcript(toolOutputs: const {}, part: summary));
      final header = tester.getRect(find.byKey(_toggle));

      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      verify(() => cubit.fetchToolOutput(messageId: "message-1", partId: "tool-1")).called(1);
      states.add(_loaded(toolOutputs: const {key: ToolOutputLoading()}));
      await tester.pump(const Duration(milliseconds: 100));
      // A quick fetch never flashes a spinner.
      expect(spinnerOpacity(tester), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(spinnerOpacity(tester), 1);
      await tester.pump(const Duration(milliseconds: 300));
      // A transcript without its output is not offered for copying.
      expect(find.byTooltip("Copy").hitTestable(), findsNothing);
      final loading = _shellHeight(tester);
      final title = tester.getRect(find.text("Shell"));

      states.add(_loaded(toolOutputs: {key: const ToolOutputLoaded(output: "line 1\nline 2\nline 3", error: null)}));
      await tester.pump();
      await tester.pump();
      expect(_shellHeight(tester), loading, reason: "the output lays out at the old height first");
      await tester.pump(const Duration(milliseconds: 100));
      final easing = _shellHeight(tester);
      expect(tester.getRect(find.byKey(_toggle)), header);
      await tester.pump(const Duration(milliseconds: 300));

      expect(easing, greaterThan(loading));
      expect(_shellHeight(tester), greaterThan(easing));
      expect(tester.getRect(find.byKey(_toggle)), header);
      expect(find.text("\$ make check\n\nline 1\nline 2\nline 3"), findsOneWidget);
      expect(find.byTooltip("Copy").hitTestable(), findsOneWidget);
      expect(tester.getRect(find.text("Shell")), title, reason: "the panel's title does not move");
      expect(tester.takeException(), isNull);
    });

    testWidgets("a failed fetch offers a retry inside the panel", (tester) async {
      await tester.pumpWidget(transcript(toolOutputs: const {key: ToolOutputFailed()}, part: summary));

      await tester.tap(find.byKey(_toggle));
      // The panel's animation starts on the first frame after the tap.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("Could not load the output."), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey("toolOutput.retry")));

      // Once on opening, which also retries, and once for the tap.
      verify(() => cubit.fetchToolOutput(messageId: "message-1", partId: "tool-1")).called(2);
      states.add(_loaded(toolOutputs: const {key: ToolOutputLoading()}));
      await tester.pump(const Duration(milliseconds: 100));
      expect(spinnerOpacity(tester), 0, reason: "a retry waits as long as the first fetch before its spinner");
      expect(tester.takeException(), isNull);
    });

    testWidgets("a failure in large text grows instead of clipping", (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(transcript(toolOutputs: const {key: ToolOutputFailed()}, part: summary));

      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final failure = find.text("Could not load the output.");
      final row = find.ancestor(of: failure, matching: find.byType(Row)).first;
      expect(tester.getSize(row).height, greaterThan(44));
      expect(tester.getSize(row).height, greaterThanOrEqualTo(tester.getSize(failure).height));
      expect(find.byKey(const ValueKey("toolOutput.retry")).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("a failure taller than the loading row eases to it", (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(transcript(toolOutputs: const {key: ToolOutputLoading()}, part: summary));
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final loading = _shellHeight(tester);

      states.add(_loaded(toolOutputs: const {key: ToolOutputFailed()}));
      await tester.pump();
      await tester.pump();
      expect(_shellHeight(tester), loading, reason: "the failure lays out at the old height first");
      await tester.pump(const Duration(milliseconds: 100));
      final easing = _shellHeight(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(easing, greaterThan(loading));
      expect(_shellHeight(tester), greaterThan(easing));
      expect(tester.takeException(), isNull);
    });

    testWidgets("an output arriving during a fling lets the fling run on", (tester) async {
      await tester.pumpWidget(transcript(toolOutputs: const {key: ToolOutputLoading()}, part: summary));
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;

      await tester.fling(find.byType(ListView), const Offset(0, 150), 1500);
      await tester.pump(const Duration(milliseconds: 16));
      states.add(_loaded(toolOutputs: {key: const ToolOutputLoaded(output: "line 1\nline 2\nline 3", error: null)}));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final during = position.pixels;
      expect(position.isScrollingNotifier.value, isTrue, reason: "the output does not stop the fling");
      await tester.pump(const Duration(milliseconds: 50));

      expect(position.pixels, isNot(during));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets("an output shorter than the loading row eases down to it", (tester) async {
      const tool = MessagePartTool(
        id: "tool-1",
        sessionID: "session-1",
        messageID: "message-1",
        tool: "Lookup",
        state: ToolState.summary(status: ToolStatus.completed, title: null, shellCommand: null, attachments: []),
      );
      await tester.pumpWidget(transcript(toolOutputs: const {key: ToolOutputLoading()}, part: tool));
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final loading = _shellHeight(tester);

      states.add(_loaded(toolOutputs: {key: const ToolOutputLoaded(output: "ok", error: null)}));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final easing = _shellHeight(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(easing, lessThan(loading));
      expect(_shellHeight(tester), lessThan(easing));
    });

    testWidgets("keeps the command's sideways scroll when the output arrives", (tester) async {
      const tool = MessagePartTool(
        id: "tool-1",
        sessionID: "session-1",
        messageID: "message-1",
        tool: "Bash",
        state: ToolState.summary(
          status: ToolStatus.completed,
          title: null,
          shellCommand: "dart test --reporter expanded --concurrency 1 test/features/session_detail/widgets",
          attachments: [],
        ),
      );
      double sidewaysOffset() => tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const ValueKey("shellTool.viewport")),
              matching: find.byWidgetPredicate(
                (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.right,
              ),
            ),
          )
          .position
          .pixels;
      await tester.pumpWidget(transcript(toolOutputs: const {key: ToolOutputLoading()}, part: tool));
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(find.byKey(const ValueKey("shellTool.viewport")), const Offset(-120, 0));
      await tester.pump();
      final scrolled = sidewaysOffset();
      expect(scrolled, greaterThan(0));

      states.add(_loaded(toolOutputs: {key: const ToolOutputLoaded(output: "ok", error: null)}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(sidewaysOffset(), scrolled);
    });

    testWidgets("an output fetched earlier opens at once", (tester) async {
      await tester.pumpWidget(
        transcript(
          toolOutputs: {key: const ToolOutputLoaded(output: "done", error: null)},
          part: summary,
        ),
      );

      await tester.tap(find.byKey(_toggle));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("\$ make check\n\ndone"), findsOneWidget);
      verifyNever(
        () => cubit.fetchToolOutput(
          messageId: any(named: "messageId"),
          partId: any(named: "partId"),
        ),
      );
    });
  });
}

class _Cubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

SessionDetailState _loaded({required Map<ToolOutputKey, ToolOutputFetch> toolOutputs}) => SessionDetailState.loaded(
  interaction: const SessionInteractionState.available(displayName: "Claude Code", refreshError: null),
  messages: const [],
  launchHandoff: null,
  olderMessagesCursor: null,
  userMessagesBeforeOldest: null,
  promptIndex: null,
  toolOutputs: toolOutputs,
  streamingText: const {},
  sessionStatus: const SessionStatus.idle(),
  pendingQuestions: const [],
  pendingPermissions: const [],
  sessionTitle: null,
  session: testConstSession,
  pluginId: "claude",
  supportsPromptAttachments: false,
  assistantAgentModel: null,
  children: const [],
  childStatuses: const {},
  isRootSession: true,
  isArchived: false,
  cannotContinueMessage: null,
  queuedMessages: const [],
  bridgePromptAttachments: const {},
  localSend: const LocalSendPhase.idle(),
  availableAgents: const [],
  availableProviders: const [],
  availableCommands: const [],
  selectedAgent: "coder",
  selectedAgentModel: null,
  promptDefaults: null,
  fastMode: false,
  stagedCommand: null,
  isRefreshing: false,
);
