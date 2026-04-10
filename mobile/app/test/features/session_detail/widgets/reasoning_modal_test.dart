import "dart:async";

import "package:bloc_test/bloc_test.dart";
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
    modelID: null,
    providerID: null,
    children: const [],
    childStatuses: const {},
    queuedMessages: const [],
    availableAgents: const [],
    availableProviders: const [],
    selectedAgent: "coder",
    selectedProviderID: "anthropic",
    selectedModelID: "claude-3-5-sonnet",
    isRefreshing: false,
  );
}

MessageWithParts _messageWithPart({
  String messageId = "msg-1",
  String partId = "part-1",
  String? text,
}) {
  return MessageWithParts(
    info: Message(
      id: messageId,
      role: "assistant",
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
}
