import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// An older bridge sends no kind, so [kind] defaults to unknown.
MessagePart _tool({
  required String id,
  required String name,
  required ToolStatus status,
  ToolKind kind = ToolKind.unknown,
}) => MessagePart.tool(
  id: id,
  sessionID: "s",
  messageID: "m",
  tool: name,
  state: ToolState(status: status, title: null, shellCommand: null, output: null, error: null),
  kind: kind,
);

MessagePart _thought({required String id, required String text}) =>
    MessagePart.reasoning(id: id, sessionID: "s", messageID: "m", text: text);

MessagePart _subAgent({required String id, required ToolStatus status}) => MessagePart.subtask(
  id: id,
  sessionID: "s",
  messageID: "m",
  description: "Explore the repo",
  taskState: ToolState(status: status, title: null, shellCommand: null, output: null, error: null),
  childSessionID: null,
);

TranscriptGroupBlock _group({required List<MessagePart> parts, Map<String, String> streamingText = const {}}) {
  final transcript = const TranscriptBuilder().build(
    messages: [
      MessageWithParts(
        info: const Message.assistant(
          id: "m",
          sessionID: "s",
          agent: null,
          modelID: null,
          providerID: null,
          time: null,
        ),
        parts: parts,
      ),
    ],
    streamingText: streamingText,
    children: const [],
    childStatuses: const {},
  );
  return transcript.blocksFor(messageId: "m").whereType<TranscriptGroupBlock>().single;
}

Widget _app({required TranscriptGroupBlock group, bool disableAnimations = false, double width = 400}) => MaterialApp(
  theme: buildPregoThemeData(brightness: Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: TranscriptGroupWidget(key: ValueKey(group.id), projectId: null, group: group),
        ),
      ),
    ),
  ),
);

final _finishedParts = [
  _thought(id: "r1", text: "Plan the change"),
  _tool(id: "t1", name: "read", status: ToolStatus.completed),
  _tool(id: "t2", name: "grep", status: ToolStatus.error),
  _subAgent(id: "k1", status: ToolStatus.completed),
];

double _height(WidgetTester tester) => tester.getSize(find.byType(TranscriptGroupWidget)).height;

void main() {
  testWidgets("a finished group collapses to one summary that eases open and shut", (tester) async {
    await tester.pumpWidget(_app(group: _group(parts: _finishedParts)));

    expect(find.text("Thought · 2 steps · 1 sub-agent"), findsOneWidget);
    expect(find.text(" · 1 failed"), findsOneWidget);
    expect(find.text("read"), findsNothing);
    expect(find.text("Explore the repo"), findsNothing);
    final collapsed = _height(tester);

    await tester.tap(find.byKey(const ValueKey("transcriptGroup.toggle.r1")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final opening = _height(tester);
    await tester.pumpAndSettle();
    final open = _height(tester);
    expect(opening, allOf(greaterThan(collapsed), lessThan(open)));
    expect(find.text("Thought"), findsOneWidget);
    expect(find.text("read"), findsOneWidget);
    expect(find.text("grep"), findsOneWidget);
    expect(find.text("Explore the repo"), findsOneWidget);
    // Finished rows say nothing; the failure keeps one signal.
    expect(find.text("Done"), findsNothing);
    expect(find.text("Failed"), findsNothing);
    expect(find.byIcon(TablerSolid.alert_circle), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey("transcriptGroup.toggle.r1")));
    await tester.pumpAndSettle();
    expect(_height(tester), collapsed);
    expect(find.text("read"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("reduced motion opens the group at once", (tester) async {
    await tester.pumpWidget(_app(group: _group(parts: _finishedParts), disableAnimations: true));
    final collapsed = _height(tester);

    await tester.tap(find.byKey(const ValueKey("transcriptGroup.toggle.r1")));
    await tester.pump();
    expect(_height(tester), greaterThan(collapsed));
    expect(find.text("read"), findsOneWidget);
  });

  testWidgets("a running step is a live row below the summary and folds in when it finishes", (tester) async {
    final running = _group(
      parts: [
        _tool(id: "t1", name: "read", status: ToolStatus.completed),
        _tool(id: "t2", name: "bash", status: ToolStatus.running),
      ],
    );
    await tester.pumpWidget(_app(group: running));

    expect(find.text("1 step"), findsOneWidget);
    expect(find.text("bash"), findsOneWidget);
    expect(find.text("read"), findsNothing);
    expect(
      tester.getTopLeft(find.text("bash")).dy,
      greaterThan(tester.getTopLeft(find.text("1 step")).dy),
    );

    final finished = _group(
      parts: [
        _tool(id: "t1", name: "read", status: ToolStatus.completed),
        _tool(id: "t2", name: "bash", status: ToolStatus.completed),
      ],
    );
    await tester.pumpWidget(_app(group: finished));
    await tester.pumpAndSettle();

    expect(find.text("2 steps"), findsOneWidget);
    expect(find.text("bash"), findsNothing);
  });

  testWidgets("a finished live row folds into its group while the count rolls", (tester) async {
    List<MessagePart> parts({required ToolStatus last}) => [
      _tool(id: "t1", name: "Read", status: ToolStatus.completed, kind: ToolKind.read),
      _tool(id: "t2", name: "Read", status: ToolStatus.completed, kind: ToolKind.read),
      _tool(id: "t3", name: "notes", status: last, kind: ToolKind.read),
    ];
    await tester.pumpWidget(
      _app(
        group: _group(parts: parts(last: ToolStatus.running)),
      ),
    );
    final live = _height(tester);
    expect(find.text("read 2 files"), findsOneWidget);

    await tester.pumpWidget(
      _app(
        group: _group(parts: parts(last: ToolStatus.completed)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Midway the live row is still there, shorter and fading, and only the
    // number rolls: the old one leaves as the new one arrives.
    expect(find.text("notes"), findsOneWidget);
    expect(_height(tester), lessThan(live));
    final opacities = tester.widgetList<Opacity>(find.ancestor(of: find.text("notes"), matching: find.byType(Opacity)));
    expect(opacities.any((opacity) => opacity.opacity > 0 && opacity.opacity < 1), isTrue);
    expect(find.text("read "), findsOneWidget);
    expect(find.text("2"), findsOneWidget);
    expect(find.text("3"), findsOneWidget);
    expect(find.text(" files"), findsOneWidget);
    expect(tester.getTopLeft(find.text("3")).dy, greaterThan(tester.getTopLeft(find.text("2")).dy));

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text("notes"), findsNothing);
    expect(find.text("read 3 files"), findsOneWidget);
    expect(_height(tester), lessThan(live));
    expect(tester.takeException(), isNull);
  });

  testWidgets("reduced motion folds a finished row and changes the count at once", (tester) async {
    List<MessagePart> parts({required ToolStatus last}) => [
      _tool(id: "t1", name: "read", status: ToolStatus.completed),
      _tool(id: "t2", name: "bash", status: last),
    ];
    await tester.pumpWidget(
      _app(
        group: _group(parts: parts(last: ToolStatus.running)),
        disableAnimations: true,
      ),
    );
    await tester.pumpWidget(
      _app(
        group: _group(parts: parts(last: ToolStatus.completed)),
        disableAnimations: true,
      ),
    );

    expect(find.text("bash"), findsNothing);
    expect(find.text("2 steps"), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets("a new live row and a group's first summary ease in", (tester) async {
    await tester.pumpWidget(
      _app(
        group: _group(
          parts: [_tool(id: "t1", name: "read", status: ToolStatus.running)],
        ),
      ),
    );
    final oneRow = _height(tester);

    await tester.pumpWidget(
      _app(
        group: _group(
          parts: [
            _tool(id: "t1", name: "read", status: ToolStatus.completed),
            _tool(id: "t2", name: "bash", status: ToolStatus.running),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // The finished row folds while the summary and the new row grow.
    expect(find.text("1 step"), findsOneWidget);
    expect(find.text("bash"), findsOneWidget);
    // The new summary already sits above the row folding into it.
    final summaryTop = tester.getTopLeft(find.text("1 step")).dy;
    expect(summaryTop, lessThan(tester.getTopLeft(find.text("read")).dy));
    expect(tester.getTopLeft(find.text("read")).dy, lessThan(tester.getTopLeft(find.text("bash")).dy));
    final midway = _height(tester);

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text("read"), findsNothing);
    expect(_height(tester), greaterThan(oneRow));
    expect(midway, lessThan(_height(tester)));
  });

  testWidgets("the summary names tool calls by kind and keeps unknown kinds as steps", (tester) async {
    await tester.pumpWidget(
      _app(
        group: _group(
          parts: [
            _thought(id: "r1", text: "Plan the change"),
            _tool(id: "t1", name: "Read", status: ToolStatus.completed, kind: ToolKind.read),
            _tool(id: "t2", name: "Read", status: ToolStatus.completed, kind: ToolKind.read),
            _tool(id: "t3", name: "Edit", status: ToolStatus.completed, kind: ToolKind.edit),
            _tool(id: "t4", name: "Bash", status: ToolStatus.error, kind: ToolKind.command),
            _tool(id: "t5", name: "Grep", status: ToolStatus.completed, kind: ToolKind.search),
            _tool(id: "t6", name: "mcp", status: ToolStatus.completed),
          ],
        ),
      ),
    );

    expect(find.text("Thought · read 2 files · edited 1 file · ran 1 command · 1 search · 1 step"), findsOneWidget);
    expect(find.text(" · 1 failed"), findsOneWidget);
  });

  testWidgets("a narrow summary ellipsizes its counts but keeps the failure count", (tester) async {
    await tester.pumpWidget(
      _app(
        width: 220,
        group: _group(
          parts: [
            _tool(id: "t1", name: "Read", status: ToolStatus.completed, kind: ToolKind.read),
            _tool(id: "t2", name: "Edit", status: ToolStatus.completed, kind: ToolKind.edit),
            _tool(id: "t3", name: "Bash", status: ToolStatus.error, kind: ToolKind.command),
            _tool(id: "t4", name: "Grep", status: ToolStatus.completed, kind: ToolKind.search),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final failed = tester.getRect(find.text(" · 1 failed"));
    final group = tester.getRect(find.byType(TranscriptGroupWidget));
    expect(failed.right, lessThanOrEqualTo(group.right));
  });

  testWidgets("a group of only running steps shows no summary", (tester) async {
    await tester.pumpWidget(
      _app(
        group: _group(
          parts: [
            _thought(id: "r1", text: ""),
            _subAgent(id: "k1", status: ToolStatus.running),
          ],
          streamingText: {"r1": "Reading the tests"},
        ),
      ),
    );

    expect(find.byType(TranscriptDisclosure), findsNothing);
    expect(find.text("Thinking..."), findsOneWidget);
    expect(find.text("Explore the repo"), findsOneWidget);
  });
}
