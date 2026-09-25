import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

MessagePart _tool({required String id, required String name, required ToolStatus status}) => MessagePart.tool(
  id: id,
  sessionID: "s",
  messageID: "m",
  tool: name,
  state: ToolState(status: status, title: null, shellCommand: null, output: null, error: null),
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

Widget _app({required TranscriptGroupBlock group, bool disableAnimations = false}) => MaterialApp(
  theme: buildPregoThemeData(brightness: Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
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

    expect(find.text("Thought · 2 steps · 1 sub-agent · 1 failed"), findsOneWidget);
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
