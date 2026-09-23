import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

const _toggle = ValueKey("shellTool.toggle");
const _panel = ValueKey("shellTool.panel");
const _viewport = ValueKey("shellTool.viewport");

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
      expect(find.byKey(_panel), findsNothing);
      expect(tester.getSize(find.byKey(_toggle)).height, greaterThanOrEqualTo(44));
      await tester.tap(find.byKey(_toggle));
      await tester.pumpAndSettle();

      final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;
      final decoration = tester.widget<Container>(find.byKey(_panel)).decoration! as BoxDecoration;
      expect(decoration.color, prego.colors.bgSurface2);
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.border?.top.color, prego.colors.borderPrimary);
      expect(tester.getSize(find.byKey(_viewport)).height, 144);
      expect(find.text("Shell"), findsOneWidget);
      expect(find.text("Done"), findsOneWidget);
      expect(find.text("\$ git status --short\n\n M file.dart"), findsOneWidget);
      await tester.tap(find.byKey(_toggle));
      await tester.pumpAndSettle();
      expect(find.byKey(_panel), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (status, label) in [
    (ToolStatus.pending, "Pending"),
    (ToolStatus.running, "Running"),
    (ToolStatus.completed, "Done"),
    (ToolStatus.error, "Failed"),
    (ToolStatus.cancelled, "Cancelled"),
    (ToolStatus.unknown, "Tool"),
  ]) {
    testWidgets("shell retains the ${status.name} status", (tester) async {
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
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      expect(find.text(label), findsOneWidget);
      if (status == ToolStatus.error) {
        expect(find.text("\$ make check\n\nCommand exited with code 1"), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("copies the exact command and output separately", (tester) async {
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
    await tester.tap(find.byTooltip("Copy command"));
    await tester.pump();
    expect(copied, command);
    await tester.tap(find.byTooltip("Copy output"));
    await tester.pump();
    expect(copied, output);
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
    final panelHeight = tester.getSize(find.byKey(_panel)).height;
    await tester.drag(viewport, const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(horizontal.offset, greaterThan(0));
    await tester.drag(viewport, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(vertical.offset, greaterThan(0));
    expect(tester.getSize(find.byKey(_panel)).height, panelHeight);
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
    expect(find.byKey(_panel), findsOneWidget);
    expect(find.text("\$ make check\n\nAll checks passed"), findsOneWidget);
    expect(find.text("Done"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("expanding a historical command stays visible in a reversed transcript", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            key: const ValueKey("transcript"),
            height: 500,
            child: ListView(
              reverse: true,
              children: [
                const SizedBox(height: 350),
                ToolPartWidget(
                  part: _part(status: ToolStatus.completed, command: "pwd", output: "result", error: null),
                ),
                const SizedBox(height: 500),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_toggle));
    await tester.pumpAndSettle();
    final transcript = tester.getRect(find.byKey(const ValueKey("transcript")));
    final header = tester.getRect(find.byKey(_toggle));
    final panel = tester.getRect(find.byKey(_panel));
    expect(header.top, greaterThan(transcript.top + 80));
    expect(panel.bottom, lessThan(transcript.bottom - 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets("shell details ease open and shut", (tester) async {
    await tester.pumpWidget(
      _app(
        part: _part(status: ToolStatus.completed, command: "pwd", output: "result", error: null),
      ),
    );
    double height() => tester.getSize(find.byType(AnimatedSize)).height;
    final closed = height();
    await tester.tap(find.byKey(_toggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final opening = height();
    await tester.pumpAndSettle();
    final open = height();
    expect(opening, allOf(greaterThan(closed), lessThan(open)));

    await tester.tap(find.byKey(_toggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(height(), allOf(greaterThan(closed), lessThan(open)));
    await tester.pumpAndSettle();
    expect(height(), closed);
  });

  testWidgets("reduced motion opens shell details at once", (tester) async {
    await tester.pumpWidget(
      _app(
        disableAnimations: true,
        part: _part(status: ToolStatus.completed, command: "pwd", output: "result", error: null),
      ),
    );
    await tester.tap(find.byKey(_toggle));
    await tester.pump();
    expect(find.byType(AnimatedSize), findsNothing);
    expect(tester.getSize(find.byKey(_viewport)).height, 144);
    expect(tester.takeException(), isNull);
  });

  testWidgets("long tool output eases open behind Show more", (tester) async {
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
    double height() => tester.getSize(find.byType(AnimatedSize)).height;
    final collapsed = height();
    await tester.tap(find.text("Show more"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final opening = height();
    await tester.pumpAndSettle();
    expect(opening, allOf(greaterThan(collapsed), lessThan(height())));
    expect(find.text("Show less"), findsOneWidget);
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
    expect(find.byKey(_panel), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(_panel), findsNothing);
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
    expect(tester.getSize(find.byKey(_panel)).width, 240);
    expect(tester.takeException(), isNull);
  });

  testWidgets("ordinary tools keep normalized titles without shell-name guessing", (tester) async {
    await tester.pumpWidget(
      _app(
        part: _part(status: ToolStatus.completed, command: null, output: "Old peer output", error: null),
      ),
    );
    expect(find.byKey(_toggle), findsNothing);
    expect(find.text("Any normalized tool name A tool title"), findsOneWidget);
    expect(find.text("Old peer output"), findsOneWidget);
    expect(find.byType(PregoCopyIconButton), findsOneWidget);
    expect(find.byIcon(TablerRegular.tool), findsOneWidget);
  });
}
