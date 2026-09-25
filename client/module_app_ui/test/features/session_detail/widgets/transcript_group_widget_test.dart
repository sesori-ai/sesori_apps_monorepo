import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_motion.dart";
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

MessagePart _subAgent({required String id, required ToolStatus status, String? childSessionID}) => MessagePart.subtask(
  id: id,
  sessionID: "s",
  messageID: "m",
  description: "Explore the repo",
  taskState: ToolState(status: status, title: null, shellCommand: null, output: null, error: null),
  childSessionID: childSessionID,
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

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

Widget _app({
  required TranscriptGroupBlock group,
  bool disableAnimations = false,
  double width = 400,
  PregoInteractionMode mode = PregoInteractionMode.touch,
  String? projectId,
  SessionDetailSessionOpener? openSession,
  // A fresh router per pump would drop widget state, so only a test that
  // pumps once and pops a sheet through go_router asks for one.
  bool routed = false,
}) {
  final page = SessionDetailPresentationScope(
    messageImageRepository: () => throw UnimplementedError(),
    imageSaver: () => throw UnimplementedError(),
    imageClipboard: () => throw UnimplementedError(),
    imageSharer: () => throw UnimplementedError(),
    canShareImages: false,
    openExternalLink: ({required url, required mode}) async => false,
    openSession: openSession ?? ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
    openHarnessSettings: () {},
    openBridgeSettings: () {},
    child: BlocProvider<SessionDetailCubit>.value(
      value: _MockSessionDetailCubit(),
      child: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: TranscriptGroupWidget(key: ValueKey(group.id), projectId: projectId, group: group),
            ),
          ),
        ),
      ),
    ),
  );
  final theme = buildPregoThemeData(brightness: Brightness.light);
  return PregoInteractionScope(
    mode: mode,
    child: routed
        ? MaterialApp.router(
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: GoRouter(
              routes: [GoRoute(path: "/", builder: (_, _) => page)],
            ),
          )
        : MaterialApp(
            theme: theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: page,
          ),
  );
}

final _finishedParts = [
  _thought(id: "r1", text: "Plan the change"),
  _tool(id: "t1", name: "read", status: ToolStatus.completed),
  _tool(id: "t2", name: "grep", status: ToolStatus.error),
  _subAgent(id: "k1", status: ToolStatus.completed),
];

double _height(WidgetTester tester) => tester.getSize(find.byType(TranscriptGroupWidget)).height;

void main() {
  testWidgets("under a pointer a group opens its steps in a popover, closed by Esc or an outside click", (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        group: _group(parts: _finishedParts),
        mode: PregoInteractionMode.pointer,
      ),
    );

    expect(find.text("Thought · 2 steps · 1 sub-agent"), findsOneWidget);
    expect(find.text(" · 1 failed"), findsOneWidget);
    expect(find.text("Read"), findsNothing);
    final collapsed = _height(tester);

    await tester.tap(find.byKey(const ValueKey("transcriptGroup.toggle.r1")));
    await tester.pumpAndSettle();
    expect(find.byType(PregoPopover), findsOneWidget);
    expect(find.text("Thought Plan the change"), findsOneWidget);
    expect(find.text("Read"), findsOneWidget);
    expect(find.text("Grep"), findsOneWidget);
    expect(find.text("Agent Explore the repo"), findsOneWidget);
    // Finished rows say nothing; the failure keeps one signal.
    expect(find.text("Done"), findsNothing);
    expect(find.text("Failed"), findsNothing);
    expect(find.byIcon(TablerSolid.alert_circle), findsOneWidget);
    // The popover sits below the summary and leaves the transcript alone.
    expect(tester.getTopLeft(find.text("Read")).dy, greaterThan(tester.getBottomLeft(find.text(" · 1 failed")).dy));
    expect(_height(tester), collapsed);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text("Read"), findsNothing);

    await tester.tap(find.byKey(const ValueKey("transcriptGroup.toggle.r1")));
    await tester.pumpAndSettle();
    expect(find.text("Read"), findsOneWidget);
    await tester.tapAt(const Offset(700, 580));
    await tester.pumpAndSettle();
    expect(find.text("Read"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("under touch a group opens its steps in a sheet titled with its summary", (tester) async {
    await tester.pumpWidget(_app(group: _group(parts: _finishedParts)));
    final collapsed = _height(tester);

    await tester.tap(find.byKey(const ValueKey("transcriptGroup.toggle.r1")));
    await tester.pumpAndSettle();
    expect(find.byType(PregoBottomSheet), findsOneWidget);
    expect(find.text("Thought · 2 steps · 1 sub-agent · 1 failed"), findsOneWidget);
    expect(find.text("Read"), findsOneWidget);
    expect(find.text("Agent Explore the repo"), findsOneWidget);
    expect(_height(tester), collapsed);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text("Read"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final mode in PregoInteractionMode.values) {
    testWidgets("opening a sub-agent from the ${mode.name} panel closes the panel first", (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        _app(
          group: _group(
            parts: [
              _subAgent(id: "k1", status: ToolStatus.completed, childSessionID: "child"),
              _tool(id: "t1", name: "read", status: ToolStatus.completed),
            ],
          ),
          mode: mode,
          projectId: "p",
          routed: true,
          openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) =>
              opened.add(sessionId),
        ),
      );
      await tester.tap(find.byKey(const ValueKey("transcriptGroup.toggle.k1")));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Agent Explore the repo"));
      await tester.pumpAndSettle();
      expect(opened, ["child"]);
      expect(find.text("Agent Explore the repo"), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("the panel's steps are selectable", (tester) async {
    await tester.pumpWidget(
      _app(
        group: _group(parts: _finishedParts),
        mode: PregoInteractionMode.pointer,
      ),
    );
    await tester.tap(find.byKey(const ValueKey("transcriptGroup.toggle.r1")));
    await tester.pumpAndSettle();
    expect(find.ancestor(of: find.text("Read"), matching: find.byType(PregoReadableSelectionArea)), findsOneWidget);
  });

  testWidgets("reduced motion opens a group's popover at once", (tester) async {
    await tester.pumpWidget(
      _app(
        group: _group(parts: _finishedParts),
        mode: PregoInteractionMode.pointer,
        disableAnimations: true,
      ),
    );
    final collapsed = _height(tester);

    await tester.tap(find.byKey(const ValueKey("transcriptGroup.toggle.r1")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text("Read"), findsOneWidget);
    final fades = tester.widgetList<Opacity>(find.ancestor(of: find.text("Read"), matching: find.byType(Opacity)));
    expect(fades.every((fade) => fade.opacity == 1), isTrue);
    expect(_height(tester), collapsed);
  });

  testWidgets("a large group's popover scrolls within its cap and never grows the transcript", (tester) async {
    final large = _group(
      parts: [for (var i = 0; i < 60; i++) _tool(id: "t$i", name: "tool $i", status: ToolStatus.completed)],
    );
    await tester.pumpWidget(_app(group: large, mode: PregoInteractionMode.pointer));
    final collapsed = _height(tester);

    await tester.tap(find.byKey(const ValueKey("transcriptGroup.toggle.t0")));
    await tester.pumpAndSettle();
    expect(find.text("Tool 0"), findsOneWidget);
    expect(_height(tester), collapsed);
    final panel = find.ancestor(of: find.text("Tool 0"), matching: find.byType(SingleChildScrollView));
    expect(tester.getSize(panel).height, lessThanOrEqualTo(TranscriptGroupWidget.panelMaxHeight));
  });

  testWidgets("a lone finished step is its own row, not a one-step summary", (tester) async {
    await tester.pumpWidget(
      _app(
        group: _group(
          parts: [_tool(id: "t1", name: "read", status: ToolStatus.completed)],
        ),
      ),
    );

    expect(find.text("Read"), findsOneWidget);
    expect(find.text("1 step"), findsNothing);
    expect(find.byKey(const ValueKey("transcriptGroup.summary")), findsNothing);
    expect(find.byType(ToolPartWidget), findsOneWidget);
  });

  testWidgets("a lone finished step keeps its place among live rows and folds in once a second finishes", (
    tester,
  ) async {
    List<MessagePart> parts({required ToolStatus first}) => [
      _tool(id: "t1", name: "bash", status: first),
      _tool(id: "t2", name: "read", status: ToolStatus.completed),
    ];
    await tester.pumpWidget(
      _app(
        group: _group(parts: parts(first: ToolStatus.running)),
      ),
    );

    // The finished step stays in step order, below the running one.
    expect(find.text("1 step"), findsNothing);
    expect(tester.getTopLeft(find.text("Read")).dy, greaterThan(tester.getTopLeft(find.text("Bash")).dy));

    await tester.pumpWidget(
      _app(
        group: _group(parts: parts(first: ToolStatus.completed)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Both rows fold into the new summary above them rather than popping.
    expect(find.text("2 steps"), findsOneWidget);
    expect(find.text("Read"), findsOneWidget);
    expect(tester.getTopLeft(find.text("2 steps")).dy, lessThan(tester.getTopLeft(find.text("Bash")).dy));

    await tester.pumpAndSettle();
    expect(find.text("Bash"), findsNothing);
    expect(find.text("Read"), findsNothing);
    expect(tester.takeException(), isNull);
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
    expect(find.text("Notes"), findsOneWidget);
    expect(_height(tester), lessThan(live));
    final opacities = tester.widgetList<Opacity>(find.ancestor(of: find.text("Notes"), matching: find.byType(Opacity)));
    expect(opacities.any((opacity) => opacity.opacity > 0 && opacity.opacity < 1), isTrue);
    expect(find.text("read "), findsOneWidget);
    expect(find.text("2"), findsOneWidget);
    expect(find.text("3"), findsOneWidget);
    expect(find.text(" files"), findsOneWidget);
    expect(tester.getTopLeft(find.text("3")).dy, greaterThan(tester.getTopLeft(find.text("2")).dy));

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text("Notes"), findsNothing);
    expect(find.text("read 3 files"), findsOneWidget);
    expect(_height(tester), lessThan(live));
    expect(tester.takeException(), isNull);
  });

  testWidgets("a step that finishes before it has eased in folds straight into the summary", (tester) async {
    List<MessagePart> parts({required ToolStatus last}) => [
      _tool(id: "t1", name: "read", status: ToolStatus.completed),
      _tool(id: "t2", name: "bash", status: last),
    ];
    await tester.pumpWidget(
      _app(
        group: _group(parts: parts(last: ToolStatus.completed).take(1).toList()),
      ),
    );
    await tester.pumpWidget(
      _app(
        group: _group(parts: parts(last: ToolStatus.running)),
      ),
    );
    await tester.pumpWidget(
      _app(
        group: _group(parts: parts(last: ToolStatus.completed)),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.text("Bash"), findsNothing);
    expect(find.text("2 steps"), findsOneWidget);
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

    expect(find.text("Bash"), findsNothing);
    expect(find.text("2 steps"), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets("a live row that finishes alone stays put, and a group's first summary eases in", (tester) async {
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
    // A running label shimmers forever, so pump past the easing.
    await tester.pump(const Duration(milliseconds: 300));
    // The finished row stays; only the new live row eased in below it.
    expect(find.text("1 step"), findsNothing);
    expect(tester.getTopLeft(find.text("Read")).dy, lessThan(tester.getTopLeft(find.text("Bash")).dy));
    final twoRows = _height(tester);
    expect(twoRows, greaterThan(oneRow));

    await tester.pumpWidget(
      _app(
        group: _group(
          parts: [
            _tool(id: "t1", name: "read", status: ToolStatus.completed),
            _tool(id: "t2", name: "bash", status: ToolStatus.completed),
            _tool(id: "t3", name: "grep", status: ToolStatus.running),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // The finished rows fold while the summary and the new row grow.
    expect(find.text("2 steps"), findsOneWidget);
    expect(find.text("Grep"), findsOneWidget);
    // The new summary already sits above the rows folding into it.
    expect(tester.getTopLeft(find.text("2 steps")).dy, lessThan(tester.getTopLeft(find.text("Read")).dy));
    expect(tester.getTopLeft(find.text("Bash")).dy, lessThan(tester.getTopLeft(find.text("Grep")).dy));
    Iterable<String> presences() => tester.stateList(find.byType(TranscriptPresence)).map((state) => "$state");
    expect(presences().where((state) => state.contains("tracking 1 ticker")), isNotEmpty);

    await tester.pump(const Duration(milliseconds: 150));
    // Settled rows hold no controller or ticker.
    expect(presences().where((state) => state.contains("tracking 1 ticker")), isEmpty);
    expect(find.text("Read"), findsNothing);
    expect(find.text("Bash"), findsNothing);
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
    expect(find.text("Agent Explore the repo"), findsOneWidget);
  });
}
