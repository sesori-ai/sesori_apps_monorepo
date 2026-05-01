import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_detail/widgets/reasoning_modal.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockSessionDetailCubit extends MockCubit<SessionDetailState> implements SessionDetailCubit {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SessionDetailState _loadedState({
  Map<String, String> streamingText = const {},
  List<MessageWithParts> messages = const [],
}) {
  return SessionDetailState.loaded(
    messages: messages,
    streamingText: streamingText,
    sessionStatus: const SessionStatus.idle(),
    pendingQuestions: const [],
    pendingPermissions: const [],
    sessionTitle: null,
    agent: null,
    assistantAgentModel: null,
    children: const [],
    childStatuses: const {},
    queuedMessages: const [],
    availableAgents: const [],
    availableProviders: const [],
    availableCommands: const [],
    selectedAgent: "coder",
    selectedAgentModel: const AgentModel(
      providerID: "anthropic",
      modelID: "claude-3-5-sonnet",
      variant: null,
    ),
    stagedCommand: null,
    isRefreshing: false,
  );
}

MessageWithParts _messageWithPart({
  String messageId = "msg-1",
  String partId = "part-1",
  String? text,
}) {
  return MessageWithParts(
    info: Message.assistant(
      id: messageId,
      sessionID: "session-1",
      agent: null,
      modelID: null,
      providerID: null,
    ),
    parts: [
      MessagePart(
        id: partId,
        sessionID: "session-1",
        messageID: messageId,
        type: MessagePartType.reasoning,
        text: text,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
      ),
    ],
  );
}

Widget _buildApp({required SessionDetailCubit cubit}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<SessionDetailCubit>.value(
      value: cubit,
      child: const Scaffold(
        body: ReasoningModal(partId: "part-1", messageId: "msg-1"),
      ),
    ),
  );
}

String _reasoningText({required int paragraphs}) {
  return List.generate(
    paragraphs,
    (index) => "Thought $index\n\n${List.generate(4, (line) => "detail $index.$line").join(" ")}",
  ).join("\n\n");
}

const _reasoningListViewKey = Key("reasoning-modal-list-view");
const _followOutputKey = Key("reasoning-modal-follow-output");

ScrollPosition _position(WidgetTester tester) {
  return tester.widget<ListView>(find.byKey(_reasoningListViewKey)).controller!.position;
}

Future<void> _sendPointerScroll({required WidgetTester tester, required Finder target, required Offset delta}) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(tester.getCenter(target)));
  await tester.pump();
  await tester.sendEventToBinding(pointer.scroll(delta));
}

void main() {
  late MockSessionDetailCubit mockCubit;

  setUp(() {
    mockCubit = MockSessionDetailCubit();
  });

  testWidgets("modal receives streaming updates in real-time", (tester) async {
    final controller = StreamController<SessionDetailState>.broadcast();
    addTearDown(controller.close);

    whenListen(
      mockCubit,
      controller.stream,
      initialState: _loadedState(
        streamingText: {"part-1": "hello"},
        messages: [_messageWithPart()],
      ),
    );

    await tester.pumpWidget(_buildApp(cubit: mockCubit));
    await tester.pumpAndSettle();

    expect(tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data, "hello");

    controller.add(
      _loadedState(
        streamingText: {"part-1": "hello world"},
        messages: [_messageWithPart()],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data, "hello world");
  });

  testWidgets("streaming ends, finalized text shown", (tester) async {
    final controller = StreamController<SessionDetailState>.broadcast();
    addTearDown(controller.close);

    whenListen(
      mockCubit,
      controller.stream,
      initialState: _loadedState(
        streamingText: {"part-1": "thinking..."},
        messages: [_messageWithPart()],
      ),
    );

    await tester.pumpWidget(_buildApp(cubit: mockCubit));
    await tester.pumpAndSettle();

    expect(tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data, "thinking...");

    controller.add(
      _loadedState(
        streamingText: {},
        messages: [_messageWithPart(text: "final thought")],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data, "final thought");
  });

  testWidgets("modal shows finalized text when opened after streaming ends", (tester) async {
    whenListen(
      mockCubit,
      const Stream<SessionDetailState>.empty(),
      initialState: _loadedState(
        streamingText: {},
        messages: [_messageWithPart(text: "completed reasoning")],
      ),
    );

    await tester.pumpWidget(_buildApp(cubit: mockCubit));
    await tester.pumpAndSettle();

    expect(tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data, "completed reasoning");
  });

  testWidgets("markdown body is wrapped in SelectionArea for cross-paragraph selection", (tester) async {
    whenListen(
      mockCubit,
      const Stream<SessionDetailState>.empty(),
      initialState: _loadedState(
        streamingText: {},
        messages: [_messageWithPart(text: "paragraph one\n\nparagraph two")],
      ),
    );

    await tester.pumpWidget(_buildApp(cubit: mockCubit));
    await tester.pumpAndSettle();

    final markdownFinder = find.byType(MarkdownBody);
    expect(markdownFinder, findsOneWidget);

    final selectionAreaFinder = find.ancestor(
      of: markdownFinder,
      matching: find.byType(SelectionArea),
    );
    expect(selectionAreaFinder, findsOneWidget);

    expect(tester.widget<MarkdownBody>(markdownFinder).selectable, false);
  });

  testWidgets("isStreaming drives header text", (tester) async {
    final controller = StreamController<SessionDetailState>.broadcast();
    addTearDown(controller.close);

    whenListen(
      mockCubit,
      controller.stream,
      initialState: _loadedState(
        streamingText: {"part-1": "in progress"},
        messages: [_messageWithPart()],
      ),
    );

    await tester.pumpWidget(_buildApp(cubit: mockCubit));
    await tester.pumpAndSettle();

    expect(find.text("Thinking..."), findsOneWidget);

    controller.add(
      _loadedState(
        streamingText: {},
        messages: [_messageWithPart(text: "done")],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Thought"), findsOneWidget);
  });

  testWidgets("user drag detaches immediately and reattaches on settle while streaming", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    whenListen(
      mockCubit,
      const Stream<SessionDetailState>.empty(),
      initialState: _loadedState(
        streamingText: {"part-1": _reasoningText(paragraphs: 40)},
        messages: [_messageWithPart()],
      ),
    );

    await tester.pumpWidget(_buildApp(cubit: mockCubit));
    await tester.pumpAndSettle();

    expect(find.byKey(_followOutputKey), findsNothing);

    // Use a larger drag (-100) because SelectionArea consumes small drags
    // for text selection initiation; scrolling requires a larger gesture.
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_reasoningListViewKey)));
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();

    expect(find.byKey(_followOutputKey), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(_followOutputKey), findsNothing);
    expect(_position(tester).pixels, greaterThanOrEqualTo(_position(tester).maxScrollExtent - 20));
  });

  testWidgets("desktop pointer scroll detaches immediately while streaming", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    whenListen(
      mockCubit,
      const Stream<SessionDetailState>.empty(),
      initialState: _loadedState(
        streamingText: {"part-1": _reasoningText(paragraphs: 40)},
        messages: [_messageWithPart()],
      ),
    );

    await tester.pumpWidget(_buildApp(cubit: mockCubit));
    await tester.pumpAndSettle();

    expect(find.byKey(_followOutputKey), findsNothing);

    await _sendPointerScroll(
      tester: tester,
      target: find.byKey(_reasoningListViewKey),
      delta: const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_followOutputKey), findsOneWidget);
  });

  testWidgets("following mode tails rapid streaming updates without stacking animations", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = StreamController<SessionDetailState>.broadcast();
    addTearDown(controller.close);

    whenListen(
      mockCubit,
      controller.stream,
      initialState: _loadedState(
        streamingText: {"part-1": _reasoningText(paragraphs: 2)},
        messages: [_messageWithPart()],
      ),
    );

    await tester.pumpWidget(_buildApp(cubit: mockCubit));
    await tester.pumpAndSettle();

    // Fire a burst of state updates at ~streaming cadence. Before the
    // rewrite, every build queued a 150ms `animateTo(maxScrollExtent)`
    // that stacked on the in-flight animation, producing jitter and
    // occasional follow-mode detachment. With coalesced `jumpTo` via
    // `ScrollFollowTracker.scheduleJumpToEdge`, each frame performs
    // at most one tail-pin.
    for (var i = 2; i < 18; i++) {
      controller.add(
        _loadedState(
          streamingText: {"part-1": _reasoningText(paragraphs: i)},
          messages: [_messageWithPart()],
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    // Viewport should be pinned at the tail, and follow mode never
    // detached despite the high-frequency update burst.
    expect(find.byKey(_followOutputKey), findsNothing);
    final position = _position(tester);
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.5));
  });
}
