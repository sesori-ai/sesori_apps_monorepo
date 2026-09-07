import "dart:async";

import "package:flutter/gestures.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class const _SessionDetailMessageListHarness({
  super.key,
  required final List<MessageWithParts> initialMessages,
  required final Map<String, String> initialStreamingText,
  final List<QueuedSessionSubmission> initialQueuedMessages = const [],
  final List<QueuedSessionPrompt> initialBridgeQueuedPrompts = const [],
  final String? initialRetryErrorMessage,
  final Future<void> Function()? onLoadOlderMessages,
  final TargetPlatform? platform,
  final EdgeInsets systemGestureInsets = EdgeInsets.zero,
}) extends StatefulWidget {
  @override
  State<_SessionDetailMessageListHarness> createState() => _SessionDetailMessageListHarnessState();
}

class _SessionDetailMessageListHarnessState() extends State<_SessionDetailMessageListHarness> {
  late List<MessageWithParts> _messages;
  late Map<String, String> _streamingText;
  late List<QueuedSessionSubmission> _queuedMessages;
  late List<QueuedSessionPrompt> _bridgeQueuedPrompts;
  QueuedSessionSubmission? _sendingSubmission;
  final List<String> cancelledBridgePromptIds = [];
  late String? _retryErrorMessage;
  bool _isLoadingOlderMessages = false;
  int? lastCancelledQueuedMessageIndex;

  @override
  void initState() {
    super.initState();
    _messages = widget.initialMessages;
    _streamingText = widget.initialStreamingText;
    _queuedMessages = widget.initialQueuedMessages;
    _bridgeQueuedPrompts = widget.initialBridgeQueuedPrompts;
    _retryErrorMessage = widget.initialRetryErrorMessage;
  }

  void startLoadingOlderMessages() {
    setState(() => _isLoadingOlderMessages = true);
  }

  void finishLoadingOlderMessages() {
    setState(() => _isLoadingOlderMessages = false);
  }

  void prependOlderMessages({required List<MessageWithParts> older}) {
    setState(() {
      _messages = [...older, ..._messages];
      _isLoadingOlderMessages = false;
    });
  }

  void appendNewestMessage(MessageWithParts message) {
    setState(() => _messages = [..._messages, message]);
  }

  void removeMessage(String messageId) {
    setState(() => _messages = [..._messages.where((m) => m.info.id != messageId)]);
  }

  void updateStreamingText({required String partId, required String text}) {
    setState(() => _streamingText = {..._streamingText, partId: text});
  }

  void setRetryErrorMessage(String? message) {
    setState(() => _retryErrorMessage = message);
  }

  void cancelQueuedMessage(int index) {
    lastCancelledQueuedMessageIndex = index;
    setState(() => _queuedMessages = [..._queuedMessages]..removeAt(index));
  }

  void enqueueSubmission(QueuedSessionSubmission submission) {
    setState(() => _queuedMessages = [..._queuedMessages, submission]);
  }

  void sendDirectly(QueuedSessionSubmission submission) {
    setState(() => _sendingSubmission = submission);
  }

  void beginSending() {
    setState(() {
      _sendingSubmission = _queuedMessages.first;
      _queuedMessages = _queuedMessages.sublist(1);
    });
  }

  void replaceFirstQueuedSubmission(QueuedSessionSubmission submission) {
    setState(() => _queuedMessages = [submission, ..._queuedMessages.skip(1)]);
  }

  /// Mirrors the cubit's atomic queued→sent swap: the delivered user message
  /// lands and the bridge entry leaves in one state emission.
  void deliverBridgePrompt({
    required String promptId,
    required MessageWithParts message,
    required int insertionIndex,
  }) {
    setState(() {
      _messages = [..._messages]..insert(insertionIndex, message);
      _bridgeQueuedPrompts = [..._bridgeQueuedPrompts.where((prompt) => prompt.id != promptId)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(platform: widget.platform, extensions: [PregoDesignSystem.light]),
      darkTheme: ThemeData(platform: widget.platform, extensions: [PregoDesignSystem.dark]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(systemGestureInsets: widget.systemGestureInsets),
        child: child!,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SessionDetailMessageList(
          bridgeQueuedPrompts: _bridgeQueuedPrompts,
          onCancelBridgeQueuedPrompt: (promptId) {
            cancelledBridgePromptIds.add(promptId);
            setState(
              () => _bridgeQueuedPrompts = [..._bridgeQueuedPrompts.where((prompt) => prompt.id != promptId)],
            );
          },
          projectId: null,
          onLoadOlderMessages: widget.onLoadOlderMessages,
          messages: _messages,
          sendingSubmission: _sendingSubmission,
          queuedMessages: _queuedMessages,
          isLoadingOlderMessages: _isLoadingOlderMessages,
          streamingText: _streamingText,
          children: const <Session>[],
          childStatuses: const <String, SessionStatus>{},
          retryErrorMessage: _retryErrorMessage,
          onCancelQueuedMessage: cancelQueuedMessage,
        ),
      ),
    );
  }
}

MessageWithParts _message({
  required String messageId,
  required String role,
  required String text,
  String? partId,
  int? createdAtMs,
  String? promptId,
}) {
  final resolvedPartId = partId ?? "$messageId-part";
  final time = createdAtMs == null ? null : MessageTime(created: createdAtMs, completed: null);

  final info = role == "user"
      ? Message.user(promptId: promptId, id: messageId, sessionID: "session-1", agent: null, time: time)
      : Message.assistant(
          id: messageId,
          sessionID: "session-1",
          agent: null,
          modelID: null,
          providerID: null,
          time: time,
        );
  return MessageWithParts(
    info: info,
    parts: [
      MessagePart.text(
        id: resolvedPartId,
        sessionID: "session-1",
        messageID: messageId,
        text: text,
      ),
    ],
  );
}

MessageWithParts _automatedMessage({
  required String messageId,
  required String text,
  required MessageSender sender,
}) {
  return MessageWithParts(
    info: Message.assistant(
      id: messageId,
      sessionID: "session-1",
      agent: null,
      modelID: null,
      providerID: null,
      sender: sender,
      time: null,
    ),
    parts: [
      MessagePart.text(
        id: "$messageId-part",
        sessionID: "session-1",
        messageID: messageId,
        text: text,
      ),
    ],
  );
}

const _emptyUserMessage = MessageWithParts(
  info: Message.user(
    promptId: null,
    id: "empty-user",
    sessionID: "session-1",
    agent: null,
    time: null,
  ),
  parts: <MessagePart>[],
);

List<MessageWithParts> _userMessages({required int count}) {
  return List.generate(
    count,
    (index) => _message(
      messageId: "user-$index",
      role: "user",
      text: _multilineText(label: "Message $index", lines: 8),
    ),
  );
}

String _multilineText({required String label, required int lines}) {
  return List.generate(lines, (index) => "$label line $index").join("\n");
}

const _listViewKey = Key("session-detail-message-list-view");
const _jumpToLatestKey = Key("session-detail-jump-to-latest");

Finder _messageKey(String messageId) => find.byKey(ValueKey(messageId));

ScrollPosition _position(WidgetTester tester) {
  return tester.widget<ListView>(find.byKey(_listViewKey)).controller!.position;
}

Future<void> _pumpListUpdate(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Future<void> _sendPointerScroll({required WidgetTester tester, required Finder target, required Offset delta}) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(pointer.hover(tester.getCenter(target)));
  await tester.pump();
  await tester.sendEventToBinding(pointer.scroll(delta));
}

Future<void> _detachViewport(WidgetTester tester) async {
  await tester.drag(find.byKey(_listViewKey), const Offset(0, -500));
  await tester.pumpAndSettle();
  if (_position(tester).pixels <= 20) {
    await tester.drag(find.byKey(_listViewKey), const Offset(0, 500));
  }
  await tester.pumpAndSettle();
  expect(_position(tester).pixels, greaterThan(20));
  expect(find.byKey(_jumpToLatestKey), findsOneWidget);
}

void main() {
  testWidgets("renders system and unknown senders as automation instead of agent output", (tester) async {
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: [
          _message(messageId: "agent", role: "assistant", text: "Agent reply"),
          _automatedMessage(messageId: "system", text: "Automation report", sender: MessageSender.system),
          _automatedMessage(messageId: "unknown", text: "Future sender", sender: MessageSender.unknown),
        ],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AssistantMessageCard), findsNWidgets(3));
    expect(find.byType(SystemMessageCard), findsNWidgets(2));
    expect(find.byType(PregoTag), findsNWidgets(2));
    expect(find.text("Automation"), findsNWidgets(2));
    expect(find.text("Agent reply"), findsOneWidget);
    expect(find.text("Automation report"), findsOneWidget);
    expect(find.text("Future sender"), findsOneWidget);
  });

  testWidgets("renders bridge-queued prompts as cancellable queued bubbles", (tester) async {
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: const [],
        initialStreamingText: const {},
        initialBridgeQueuedPrompts: const [
          QueuedSessionPrompt(id: "prm_1", text: "steer it", command: null, attachmentCount: 1, createdAt: 100),
          QueuedSessionPrompt(id: "prm_2", text: "src", command: "review", attachmentCount: 0, createdAt: 200),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("steer it"), findsOneWidget);
    expect(find.text("1 image"), findsOneWidget);
    expect(find.text("/review src"), findsOneWidget);
    expect(find.text("Cancel"), findsNWidgets(2));

    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text("steer it"), matching: find.byType(QueuedMessageBubble)),
        matching: find.text("Cancel"),
      ),
    );
    await tester.pumpAndSettle();

    expect(harnessKey.currentState?.cancelledBridgePromptIds, ["prm_1"]);
    expect(find.text("steer it"), findsNothing);
    expect(find.text("/review src"), findsOneWidget);
  });

  testWidgets("renders an unavailable local command as removable instead of queued", (tester) async {
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: const [],
        initialStreamingText: const {},
        initialQueuedMessages: const [
          QueuedSessionSubmission.unavailableCommand(
            promptId: "prm_unavailable",
            text: "src",
            command: "review",
            agent: "coder",
            agentModel: null,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("/review src"), findsOneWidget);
    expect(find.text("Command unavailable"), findsOneWidget);
    expect(find.text("Queued command"), findsNothing);
    expect(find.widgetWithText(TextButton, "Remove"), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, "Remove"));
    await tester.pumpAndSettle();

    expect(harnessKey.currentState?.lastCancelledQueuedMessageIndex, 0);
    expect(find.text("/review src"), findsNothing);
  });

  testWidgets("a bridge-queued prompt transforms into its message without a blank frame", (tester) async {
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: [_message(messageId: "assistant-1", role: "assistant", text: "working on it")],
        initialStreamingText: const {},
        initialBridgeQueuedPrompts: const [
          QueuedSessionPrompt(id: "prm_1", text: "steer it", command: null, attachmentCount: 0, createdAt: 100),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("steer it"), findsOneWidget);
    expect(find.byType(QueuedMessageBubble), findsOneWidget);

    harnessKey.currentState?.deliverBridgePrompt(
      promptId: "prm_1",
      message: _message(messageId: "replay-user-1", role: "user", text: "steer it", promptId: "prm_1"),
      insertionIndex: 1,
    );

    // The prompt's text must stay on screen through every frame of the
    // handoff — the row transforms in place, it never blinks out.
    await tester.pump();
    expect(find.text("steer it"), findsOneWidget);
    await tester.pump();
    expect(find.text("steer it"), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text("steer it"), findsOneWidget);
    expect(find.byType(QueuedMessageBubble), findsNothing);
    expect(find.byType(UserMessageCard), findsOneWidget);
  });

  testWidgets("a moved delivered prompt keeps its row state", (tester) async {
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: [
          _message(messageId: "assistant-1", role: "assistant", text: "First reply"),
          _message(messageId: "assistant-2", role: "assistant", text: "Second reply"),
        ],
        initialStreamingText: const {},
        initialBridgeQueuedPrompts: const [
          QueuedSessionPrompt(id: "prm_1", text: "steer it", command: null, attachmentCount: 0, createdAt: 100),
        ],
      ),
    );
    await tester.pumpAndSettle();
    final promptRow = find.ancestor(of: find.text("steer it"), matching: find.byType(AnimatedSize));
    final before = tester.state(promptRow);

    harnessKey.currentState!.deliverBridgePrompt(
      promptId: "prm_1",
      message: _message(messageId: "delivered", role: "user", text: "steer it", promptId: "prm_1"),
      insertionIndex: 1,
    );
    await tester.pump();

    expect(tester.state(promptRow), same(before));
  });

  testWidgets("moving a delivered bridge prompt through assistant rows keeps every row unique", (tester) async {
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: [
          _message(messageId: "assistant-before", role: "assistant", text: "Before steer", createdAtMs: 100),
          _message(messageId: "assistant-after-1", role: "assistant", text: "First reply", createdAtMs: 300),
          _message(messageId: "assistant-after-2", role: "assistant", text: "Second reply", createdAtMs: 400),
        ],
        initialStreamingText: const {},
        initialBridgeQueuedPrompts: const [
          QueuedSessionPrompt(id: "prm_1", text: "steer it", command: null, attachmentCount: 0, createdAt: 200),
        ],
      ),
    );
    await tester.pumpAndSettle();

    harnessKey.currentState?.deliverBridgePrompt(
      promptId: "prm_1",
      message: _message(
        messageId: "replay-user-1",
        role: "user",
        text: "steer it",
        promptId: "prm_1",
        createdAtMs: 200,
      ),
      insertionIndex: 1,
    );

    for (var frame = 0; frame < 3; frame++) {
      await tester.pump();
      expect(find.text("steer it"), findsOneWidget);
      expect(find.text("Before steer"), findsOneWidget);
      expect(find.text("First reply"), findsOneWidget);
      expect(find.text("Second reply"), findsOneWidget);
    }
    await tester.pumpAndSettle();
    expect(find.byType(UserMessageCard), findsOneWidget);
    expect(find.text("First reply"), findsOneWidget);
    expect(find.text("Second reply"), findsOneWidget);
    expect(tester.getTopLeft(find.text("Before steer")).dy, lessThan(tester.getTopLeft(find.text("steer it")).dy));
    expect(tester.getTopLeft(find.text("steer it")).dy, lessThan(tester.getTopLeft(find.text("First reply")).dy));
  });

  testWidgets("does not render a user envelope until it has visible parts", (tester) async {
    final key = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: key,
        initialMessages: const [_emptyUserMessage],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(_messageKey("empty-user"), findsNothing);

    key.currentState!.appendNewestMessage(
      _message(messageId: "visible-user", role: "user", text: "Visible prompt"),
    );
    await _pumpListUpdate(tester);

    expect(find.text("Visible prompt"), findsOneWidget);
    expect(_messageKey("empty-user"), findsNothing);
  });

  testWidgets("an older page appears after it is prepended while scrolled back", (tester) async {
    final key = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: key,
        initialMessages: [
          for (var index = 10; index < 40; index++)
            _message(messageId: "m$index", role: "user", text: "message $index"),
        ],
        initialStreamingText: const {},
        onLoadOlderMessages: () async {},
      ),
    );
    await tester.pumpAndSettle();

    // Scrolling back detaches the follow tracker, which is what happens the
    // moment a user reaches for older history.
    await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 600));
    await tester.pumpAndSettle();

    key.currentState!.startLoadingOlderMessages();
    await tester.pump();
    key.currentState!.prependOlderMessages(
      older: [
        for (var index = 0; index < 10; index++) _message(messageId: "m$index", role: "user", text: "message $index"),
      ],
    );
    await tester.pumpAndSettle();

    // Scroll the rest of the way back to look for the oldest message.
    for (var attempt = 0; attempt < 15; attempt++) {
      await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 600));
      await tester.pumpAndSettle();
    }

    expect(
      find.textContaining("message 0"),
      findsOneWidget,
      reason: "an older page must render once loaded, not wait for the user to return to the newest message",
    );
  });

  testWidgets("an older page still appears when a frozen message is removed during loading", (tester) async {
    final key = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: key,
        initialMessages: [
          for (var index = 10; index < 40; index++)
            _message(messageId: "m$index", role: "user", text: "message $index"),
        ],
        initialStreamingText: const {},
        onLoadOlderMessages: () async {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 600));
    await tester.pumpAndSettle();
    key.currentState!.startLoadingOlderMessages();
    await tester.pump();
    key.currentState!.removeMessage("m20");
    await tester.pump();
    key.currentState!.prependOlderMessages(
      older: [
        for (var index = 0; index < 10; index++) _message(messageId: "m$index", role: "user", text: "message $index"),
      ],
    );
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 15; attempt++) {
      await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 600));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining("message 0"), findsOneWidget);
  });

  testWidgets("scrolling back through history requests the older page", (tester) async {
    var requested = 0;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: [
          for (var index = 0; index < 40; index++) _message(messageId: "m$index", role: "user", text: "message $index"),
        ],
        initialStreamingText: const {},
        onLoadOlderMessages: () async => requested++,
      ),
    );
    await tester.pumpAndSettle();

    // Drag downward: in a reversed list that scrolls back through history.
    for (var attempt = 0; attempt < 12 && requested == 0; attempt++) {
      await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 600));
      await tester.pumpAndSettle();
    }

    expect(requested, greaterThan(0), reason: "reaching the oldest message must load the next page");
  });

  testWidgets("nearing the oldest edge prefetches the older page before reaching it", (tester) async {
    var requested = 0;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
        onLoadOlderMessages: () async => requested++,
      ),
    );
    await tester.pumpAndSettle();

    // Small increments so the scroll never lands exactly on the edge: the
    // request must come from a mid-scroll update inside the prefetch band.
    for (var attempt = 0; attempt < 60 && requested == 0; attempt++) {
      await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 200));
      await tester.pump();
    }

    expect(requested, 1);
    expect(
      _position(tester).extentAfter,
      greaterThan(0),
      reason: "the older page must be requested before the scroll reaches the oldest edge",
    );
  });

  testWidgets("older-page requests do not overlap and retry after completion", (tester) async {
    final completions = <Completer<void>>[];
    var requested = 0;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
        onLoadOlderMessages: () {
          requested++;
          final completion = Completer<void>();
          completions.add(completion);
          return completion.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 12 && requested == 0; attempt++) {
      await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 600));
      await tester.pump();
    }
    await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 100));
    await tester.pump();
    expect(requested, 1);

    completions.single.complete();
    await tester.pump();
    await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 100));
    await tester.pump();
    expect(requested, 2);
  });

  testWidgets("older-page request retries after error without an unhandled exception", (tester) async {
    var requested = 0;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
        onLoadOlderMessages: () async {
          requested++;
          throw StateError("load failed");
        },
      ),
    );
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 12 && requested == 0; attempt++) {
      await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 600));
      await tester.pump();
    }
    await tester.pump();
    await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 100));
    await tester.pump();

    expect(requested, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets("parent loading state suppresses older-page requests", (tester) async {
    final key = GlobalKey<_SessionDetailMessageListHarnessState>();
    var requested = 0;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: key,
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
        onLoadOlderMessages: () async => requested++,
      ),
    );
    await tester.pumpAndSettle();
    key.currentState!.startLoadingOlderMessages();
    await tester.pump();

    for (var attempt = 0; attempt < 12; attempt++) {
      await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 600));
      await tester.pump();
    }
    expect(requested, 0);

    key.currentState!.finishLoadingOlderMessages();
    await tester.pump();
    await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 100));
    await tester.pump();
    expect(requested, 1);
  });

  testWidgets("detached viewport stays stable when a new newest message arrives", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    await _detachViewport(tester);
    final anchor = _messageKey("user-7");
    final before = tester.getTopLeft(anchor).dy;

    harnessKey.currentState!.appendNewestMessage(
      _message(
        messageId: "user-new",
        role: "user",
        text: _multilineText(label: "Newest message", lines: 10),
      ),
    );
    await _pumpListUpdate(tester);

    final after = tester.getTopLeft(anchor).dy;
    expect(after, closeTo(before, 0.1));
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);
  });

  testWidgets("detached viewport stays stable when newest streaming content grows", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const streamingPartId = "assistant-stream-part";
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: [
          ..._userMessages(count: 12),
          _message(
            messageId: "assistant-newest",
            role: "assistant",
            text: "",
            partId: streamingPartId,
          ),
        ],
        initialStreamingText: {
          streamingPartId: _multilineText(label: "Streaming newest", lines: 2),
        },
      ),
    );
    await tester.pumpAndSettle();

    await _detachViewport(tester);
    final anchor = _messageKey("user-7");
    final before = tester.getTopLeft(anchor).dy;

    harnessKey.currentState!.updateStreamingText(
      partId: streamingPartId,
      text: _multilineText(label: "Streaming newest", lines: 18),
    );
    await _pumpListUpdate(tester);

    final after = tester.getTopLeft(anchor).dy;
    expect(after, closeTo(before, 0.1));
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);
  });

  testWidgets("following mode stays pinned to latest", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 10),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(_position(tester).pixels, 0);
    expect(find.byKey(_jumpToLatestKey), findsNothing);

    harnessKey.currentState!.appendNewestMessage(
      _message(
        messageId: "user-following",
        role: "user",
        text: _multilineText(label: "Following newest", lines: 12),
      ),
    );
    await _pumpListUpdate(tester);

    expect(_position(tester).pixels, 0);
    expect(find.byKey(_jumpToLatestKey), findsNothing);
    expect(_messageKey("user-following"), findsOneWidget);
  });

  testWidgets("small user drag detaches immediately and only reattaches after settling near latest", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_jumpToLatestKey), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_listViewKey)));
    await gesture.moveBy(const Offset(0, -12));
    await tester.pump();

    expect(find.byKey(_jumpToLatestKey), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(_position(tester).pixels, lessThanOrEqualTo(20));
    expect(find.byKey(_jumpToLatestKey), findsNothing);
  });

  testWidgets("desktop pointer scroll detaches immediately", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_jumpToLatestKey), findsNothing);

    await _sendPointerScroll(
      tester: tester,
      target: find.byKey(_listViewKey),
      delta: const Offset(0, 500),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_jumpToLatestKey), findsOneWidget);
  });

  testWidgets("programmatic scroll changes do not detach follow mode", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    await _detachViewport(tester);

    await tester.tap(find.byKey(_jumpToLatestKey));
    await tester.pump();

    expect(find.byKey(_jumpToLatestKey), findsNothing);

    await tester.pumpAndSettle();

    expect(_position(tester).pixels, 0);
  });

  testWidgets("canceling a queued row while detached removes its frozen row", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const submission = QueuedSessionSubmission.text(
      promptId: "prompt-1",
      text: "Queued while reading history",
      inputMode: ComposerInputMode.typed,
      attachments: [],
      agent: "coder",
      agentModel: null,
    );
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
        initialQueuedMessages: const [submission],
      ),
    );
    await tester.pumpAndSettle();

    await _sendPointerScroll(
      tester: tester,
      target: find.byKey(_listViewKey),
      delta: const Offset(0, 30),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);
    expect(find.widgetWithText(TextButton, "Cancel"), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, "Cancel"));
    await _pumpListUpdate(tester);

    expect(harnessKey.currentState!.lastCancelledQueuedMessageIndex, 0);
    expect(find.text("Queued while reading history"), findsNothing);
    expect(find.widgetWithText(TextButton, "Cancel"), findsNothing);
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);
  });

  testWidgets("submitting while detached returns to latest and shows the inline row", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const submission = QueuedSessionSubmission.text(
      promptId: "prompt-1",
      text: "New prompt from history",
      inputMode: ComposerInputMode.typed,
      attachments: [],
      agent: "coder",
      agentModel: null,
    );
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();
    await _detachViewport(tester);

    harnessKey.currentState!.enqueueSubmission(submission);
    await tester.pumpAndSettle();

    expect(find.text("New prompt from history"), findsOneWidget);
    expect(find.byKey(_jumpToLatestKey), findsNothing);
    expect(_position(tester).pixels, 0);
  });

  testWidgets("promotion to sending stays live without reattaching a detached reader", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const submission = QueuedSessionSubmission.text(
      promptId: "prompt-1",
      text: "Queued before reconnect",
      inputMode: ComposerInputMode.typed,
      attachments: [],
      agent: "coder",
      agentModel: null,
    );
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
        initialQueuedMessages: const [submission],
      ),
    );
    await tester.pumpAndSettle();
    await _sendPointerScroll(
      tester: tester,
      target: find.byKey(_listViewKey),
      delta: const Offset(0, 30),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);

    harnessKey.currentState!.beginSending();
    await _pumpListUpdate(tester);

    expect(find.text("Sending"), findsOneWidget);
    // The outgoing status rail cross-fades out; settle it before asserting
    // the cancel affordance is gone.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(TextButton, "Cancel"), findsNothing);
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);
  });

  testWidgets("an unavailable-command transition does not reattach a detached reader", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const queued = QueuedSessionSubmission.command(
      promptId: "prompt-1",
      text: "src",
      command: "review",
      agent: "coder",
      agentModel: null,
    );
    const unavailable = QueuedSessionSubmission.unavailableCommand(
      promptId: "prompt-1",
      text: "src",
      command: "review",
      agent: "coder",
      agentModel: null,
    );
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
        initialQueuedMessages: const [queued],
      ),
    );
    await tester.pumpAndSettle();
    await _sendPointerScroll(
      tester: tester,
      target: find.byKey(_listViewKey),
      delta: const Offset(0, 30),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);

    harnessKey.currentState!.replaceFirstQueuedSubmission(unavailable);
    await _pumpListUpdate(tester);

    expect(find.text("Command unavailable"), findsOneWidget);
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);
  });

  testWidgets("a new direct-to-sending submission returns a detached reader to latest", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const submission = QueuedSessionSubmission.text(
      promptId: "prompt-1",
      text: "Direct sending prompt",
      inputMode: ComposerInputMode.typed,
      attachments: [],
      agent: "coder",
      agentModel: null,
    );
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();
    await _detachViewport(tester);

    harnessKey.currentState!.sendDirectly(submission);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 181));
    await tester.pump();

    expect(find.text("Direct sending prompt"), findsOneWidget);
    expect(find.text("Sending"), findsOneWidget);
    expect(find.byKey(_jumpToLatestKey), findsNothing);
    expect(_position(tester).pixels, 0);
  });

  // --- Regression tests for the old "jump to top" / "view shifts" bugs ---

  testWidgets("detached chat stays away from edge during rapid appends", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    await _detachViewport(tester);
    final detachedOffset = _position(tester).pixels;
    expect(detachedOffset, greaterThan(20));

    // Simulates a burst of SSE-driven appends while the user reads
    // history. Before the rewrite, stale-capture post-frame jumps
    // would clamp the viewport back toward `0` — reproducing the
    // "jumps all the way to the oldest message" symptom. The two-pump
    // helper lets any delayed post-frame scroll adjustment run before
    // we assert.
    for (var i = 0; i < 10; i++) {
      harnessKey.currentState!.appendNewestMessage(
        _message(
          messageId: "burst-$i",
          role: "user",
          text: _multilineText(label: "Burst $i", lines: 6),
        ),
      );
      await _pumpListUpdate(tester);
      expect(_position(tester).pixels, greaterThan(20));
      expect(find.byKey(_jumpToLatestKey), findsOneWidget);
    }

    // Scroll offset must not have collapsed anywhere near the edge
    // during the burst — assert we're still comfortably detached.
    expect(_position(tester).pixels, greaterThan(20));
  });

  testWidgets("rapid streaming updates during an active drag never jump to edge", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const streamingPartId = "assistant-stream-part";
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: [
          ..._userMessages(count: 12),
          _message(
            messageId: "assistant-newest",
            role: "assistant",
            text: "",
            partId: streamingPartId,
          ),
        ],
        initialStreamingText: {streamingPartId: _multilineText(label: "Streaming", lines: 2)},
      ),
    );
    await tester.pumpAndSettle();

    // Start a live drag INTO history. `reverse: true` maps positive-y
    // gesture to increasing scroll offset (i.e. scrolling toward older
    // content, away from the newest-at-bottom edge).
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_listViewKey)));
    // Establish vertical intent first so the timestamp recognizer leaves the
    // arena, matching the stream of move events produced by a real drag.
    await gesture.moveBy(const Offset(0, 12));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 288));
    await tester.pump();
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);
    expect(_position(tester).pixels, greaterThan(20));

    // Interleave rapid streaming text updates with further drag
    // movement. Before the rewrite, each update queued a stale
    // post-frame jump that could yank the viewport to offset 0 mid-
    // drag — this test locks that door shut.
    for (var i = 0; i < 8; i++) {
      harnessKey.currentState!.updateStreamingText(
        partId: streamingPartId,
        text: _multilineText(label: "Streaming", lines: 2 + i * 2),
      );
      await tester.pump(const Duration(milliseconds: 16));

      await gesture.moveBy(const Offset(0, 24));
      await tester.pump(const Duration(milliseconds: 16));

      expect(_position(tester).pixels, greaterThan(20));
    }

    await gesture.up();
    await tester.pumpAndSettle();

    // After release we're still detached — drag moved well away from
    // the reattach zone — so the pill remains and the viewport has
    // not snapped to the newest message.
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);
    expect(_position(tester).pixels, greaterThan(20));
  });

  // --- Reattach and content-update coverage ---

  testWidgets("reattach catches up on messages that arrived while detached", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    await _detachViewport(tester);

    // Arrives while frozen: the detached snapshot must not surface it yet.
    harnessKey.currentState!.appendNewestMessage(
      _message(
        messageId: "user-while-detached",
        role: "user",
        text: _multilineText(label: "Arrived while detached", lines: 6),
      ),
    );
    await _pumpListUpdate(tester);
    expect(_messageKey("user-while-detached"), findsNothing);

    // Reattaching must reveal the message at the newest edge.
    await tester.tap(find.byKey(_jumpToLatestKey));
    await tester.pumpAndSettle();

    expect(_position(tester).pixels, 0);
    expect(find.byKey(_jumpToLatestKey), findsNothing);
    expect(_messageKey("user-while-detached"), findsOneWidget);
  });

  testWidgets("retry error renders as the newest row and disappears when cleared", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // NOTE: RetryErrorMessageCard runs a repeating shimmer animation, so
    // this test must never call pumpAndSettle while the card is visible.
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 3),
        initialStreamingText: const {},
        initialRetryErrorMessage: "Provider is overloaded",
      ),
    );
    await tester.pump();

    final retryCard = find.byType(RetryErrorMessageCard);
    expect(retryCard, findsOneWidget);

    // The synthetic row must sit at the visual bottom — below the
    // newest real message — exactly like the old reverse-list index 0.
    final newestMessageBottom = tester.getBottomLeft(_messageKey("user-2")).dy;
    expect(tester.getCenter(retryCard).dy, greaterThan(newestMessageBottom));

    harnessKey.currentState!.setRetryErrorMessage(null);
    await _pumpListUpdate(tester);

    expect(find.byType(RetryErrorMessageCard), findsNothing);
    expect(_messageKey("user-2"), findsOneWidget);
  });

  testWidgets("removing a message while following drops its row and stays pinned", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 12),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    expect(_messageKey("user-10"), findsOneWidget);

    harnessKey.currentState!.removeMessage("user-10");
    await _pumpListUpdate(tester);

    expect(_messageKey("user-10"), findsNothing);
    expect(_messageKey("user-11"), findsOneWidget);
    expect(_position(tester).pixels, 0);
    expect(find.byKey(_jumpToLatestKey), findsNothing);
  });

  testWidgets("streaming text growth is visible while following", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const streamingPartId = "assistant-stream-part";
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: [
          _message(
            messageId: "assistant-newest",
            role: "assistant",
            text: "",
            partId: streamingPartId,
          ),
        ],
        initialStreamingText: const {streamingPartId: "Streaming start"},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("Streaming start", findRichText: true), findsOneWidget);
    expect(find.textContaining("freshly streamed token", findRichText: true), findsNothing);

    // Content updates must reach the visible row through the rebuilt list on the very
    // next frame while the list stays pinned to the newest edge.
    harnessKey.currentState!.updateStreamingText(
      partId: streamingPartId,
      text: "Streaming start with a freshly streamed token",
    );
    await tester.pump();

    expect(find.textContaining("freshly streamed token", findRichText: true), findsOneWidget);
    expect(_position(tester).pixels, 0);
    expect(find.byKey(_jumpToLatestKey), findsNothing);
  });

  testWidgets("horizontal drag peeks timestamps without scrolling, then springs back", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final created = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: [
          for (var i = 0; i < 12; i++)
            _message(
              messageId: "u$i",
              role: "user",
              text: _multilineText(label: "Message $i", lines: 6),
              createdAtMs: created,
            ),
        ],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    // Every row is wrapped with the reveal widget, carrying its message's
    // creation time through to the timestamp gutter.
    final reveals = tester.widgetList<MessageTimestampReveal>(find.byType(MessageTimestampReveal));
    expect(reveals, isNotEmpty);
    expect(reveals.every((r) => r.createdAtMs == created), isTrue);
    expect(find.byKey(_jumpToLatestKey), findsNothing);

    final textFinder = find.textContaining("Message 11").first;
    final restX = tester.getTopLeft(textFinder).dx;
    final restPixels = _position(tester).pixels;

    // A horizontal drag should peek the timestamp — sliding the content
    // left — without scrolling the list or detaching follow mode.
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_listViewKey)));
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();

    expect(
      tester.getTopLeft(textFinder).dx,
      lessThan(restX),
      reason: "content should slide left to expose the timestamp",
    );
    expect(_position(tester).pixels, restPixels, reason: "horizontal peek must not scroll the list");
    expect(find.byKey(_jumpToLatestKey), findsNothing, reason: "horizontal peek must not detach follow mode");

    // Releasing springs the transcript back to its resting position.
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(textFinder).dx, closeTo(restX, 0.5));
  });

  testWidgets("iOS system-back edge does not peek timestamps", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final created = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        platform: TargetPlatform.iOS,
        initialMessages: [
          for (var i = 0; i < 12; i++)
            _message(
              messageId: "u$i",
              role: "user",
              text: _multilineText(label: "Message $i", lines: 6),
              createdAtMs: created,
            ),
        ],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    final textFinder = find.textContaining("Message 11").first;
    final restX = tester.getTopLeft(textFinder).dx;
    final y = tester.getCenter(find.byKey(_listViewKey)).dy;

    final edgeGesture = await tester.startGesture(Offset(40, y));
    await edgeGesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    expect(tester.getTopLeft(textFinder).dx, restX);
    await edgeGesture.up();

    final contentGesture = await tester.startGesture(Offset(140, y));
    await contentGesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    expect(tester.getTopLeft(textFinder).dx, lessThan(restX));
    await contentGesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets("Android gesture navigation keeps both system-back edges out of timestamp peeks", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final created = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        platform: TargetPlatform.android,
        systemGestureInsets: const EdgeInsets.symmetric(horizontal: 24),
        initialMessages: [
          for (var i = 0; i < 12; i++)
            _message(
              messageId: "u$i",
              role: "user",
              text: _multilineText(label: "Message $i", lines: 6),
              createdAtMs: created,
            ),
        ],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    final textFinder = find.textContaining("Message 11").first;
    final restX = tester.getTopLeft(textFinder).dx;
    final y = tester.getCenter(find.byKey(_listViewKey)).dy;

    final startEdgeGesture = await tester.startGesture(Offset(40, y));
    await startEdgeGesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    expect(tester.getTopLeft(textFinder).dx, restX);
    await startEdgeGesture.up();

    final endEdgeGesture = await tester.startGesture(Offset(860, y));
    await endEdgeGesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    expect(tester.getTopLeft(textFinder).dx, restX);
    await endEdgeGesture.up();

    final contentGesture = await tester.startGesture(Offset(450, y));
    await contentGesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    expect(tester.getTopLeft(textFinder).dx, lessThan(restX));
    await contentGesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets("a fenced code block scrolls horizontally without peeking timestamps", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final created = DateTime.now().millisecondsSinceEpoch;
    final longCode = List.filled(16, "final horizontalOverflow = true; ").join();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: [
          ..._userMessages(count: 10),
          _message(
            messageId: "assistant-code",
            role: "assistant",
            text: "```dart\n$longCode\n```",
            createdAtMs: created,
          ),
        ],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    final codeBlockFinder = find.byType(CodeBlock);
    expect(codeBlockFinder, findsOneWidget);
    final horizontalScrollableFinder = find.descendant(
      of: codeBlockFinder,
      matching: find.byWidgetPredicate(
        (widget) => widget is Scrollable && axisDirectionToAxis(widget.axisDirection) == Axis.horizontal,
      ),
    );
    expect(horizontalScrollableFinder, findsOneWidget);

    final codeBlockRestX = tester.getTopLeft(codeBlockFinder).dx;
    final transcriptRestPixels = _position(tester).pixels;
    final horizontalPosition = tester.state<ScrollableState>(horizontalScrollableFinder).position;
    expect(horizontalPosition.pixels, 0);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(SingleChildScrollView)));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(horizontalPosition.pixels, greaterThan(0));
    expect(tester.getTopLeft(codeBlockFinder).dx, closeTo(codeBlockRestX, 0.5));
    expect(_position(tester).pixels, transcriptRestPixels);
    expect(find.byKey(_jumpToLatestKey), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();

    final touchScrollPixels = horizontalPosition.pixels;
    final trackpad = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    final trackpadOrigin = tester.getCenter(find.byType(SingleChildScrollView));
    await trackpad.panZoomStart(trackpadOrigin);
    for (var i = 1; i <= 6; i++) {
      await trackpad.panZoomUpdate(trackpadOrigin, pan: Offset(40.0 * i, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(horizontalPosition.pixels, lessThan(touchScrollPixels));
    expect(tester.getTopLeft(codeBlockFinder).dx, closeTo(codeBlockRestX, 0.5));
    expect(find.byKey(_jumpToLatestKey), findsNothing);

    await trackpad.panZoomEnd();
    await tester.pumpAndSettle();
  });

  testWidgets("peeking timestamps while detached does not snap back to the latest edge", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final created = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: [
          for (var i = 0; i < 12; i++)
            _message(
              messageId: "u$i",
              role: "user",
              text: _multilineText(label: "Message $i", lines: 6),
              createdAtMs: created,
            ),
        ],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    // Scroll up into history so the list is detached from the edge.
    await _detachViewport(tester);
    final detachedPixels = _position(tester).pixels;

    // A horizontal peek must reveal timestamps without re-attaching follow
    // mode or moving the reader's scroll position.
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_listViewKey)));
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();

    expect(find.byKey(_jumpToLatestKey), findsOneWidget, reason: "peek must not re-attach follow mode while detached");
    expect(_position(tester).pixels, detachedPixels, reason: "peek must not move the scroll position");

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      find.byKey(_jumpToLatestKey),
      findsOneWidget,
      reason: "still detached at the same spot after the peek closes",
    );
  });

  testWidgets("a second finger during a peek does not hijack or cancel it", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final created = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: [
          for (var i = 0; i < 12; i++)
            _message(
              messageId: "u$i",
              role: "user",
              text: _multilineText(label: "Message $i", lines: 6),
              createdAtMs: created,
            ),
        ],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    final textFinder = find.textContaining("Message 11").first;
    final restX = tester.getTopLeft(textFinder).dx;

    // Finger A engages the peek.
    final pointerA = await tester.startGesture(const Offset(450, 350));
    await pointerA.moveBy(const Offset(-160, 0));
    await tester.pump();
    final peekedX = tester.getTopLeft(textFinder).dx;
    expect(peekedX, lessThan(restX));

    // A stray second finger lands and lifts; it must not hijack the
    // gesture or spring the peek shut.
    final pointerB = await tester.startGesture(const Offset(200, 300));
    await pointerB.up();
    await tester.pump();
    expect(tester.getTopLeft(textFinder).dx, peekedX, reason: "secondary pointer must not cancel the active peek");

    // The owning finger lifts: now it springs back.
    await pointerA.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(textFinder).dx, closeTo(restX, 0.5));
  });

  testWidgets("a trackpad pan during a touch peek does not hijack or cancel it", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final created = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: [
          for (var i = 0; i < 12; i++)
            _message(
              messageId: "u$i",
              role: "user",
              text: _multilineText(label: "Message $i", lines: 6),
              createdAtMs: created,
            ),
        ],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    final textFinder = find.textContaining("Message 11").first;
    final restX = tester.getTopLeft(textFinder).dx;

    // A finger drag engages the peek.
    final finger = await tester.startGesture(const Offset(450, 350));
    await finger.moveBy(const Offset(-160, 0));
    await tester.pump();
    final peekedX = tester.getTopLeft(textFinder).dx;
    expect(peekedX, lessThan(restX));

    // On a device with both a touchscreen and a trackpad, a stray trackpad
    // pan-zoom must not seize the shared reveal state from the active touch
    // drag — the finger owns the peek until it lifts.
    final trackpad = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await trackpad.panZoomStart(const Offset(200, 300));
    await trackpad.panZoomUpdate(const Offset(200, 300), pan: const Offset(-120, 0));
    await trackpad.panZoomEnd();
    // Settle so that any spurious spring-back the stray pan triggered would
    // run to completion (and fail the assertion) rather than hide behind an
    // in-flight animation.
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(textFinder).dx,
      peekedX,
      reason: "trackpad pan must not hijack or close the active touch peek",
    );

    // The owning finger lifts: now it springs back.
    await finger.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(textFinder).dx, closeTo(restX, 0.5));
  });

  testWidgets("a rightward-first drag yields when it turns into a vertical scroll", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final created = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: [
          for (var i = 0; i < 12; i++)
            _message(
              messageId: "u$i",
              role: "user",
              text: _multilineText(label: "Message $i", lines: 6),
              createdAtMs: created,
            ),
        ],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    final textFinder = find.textContaining("Message 11").first;
    final restX = tester.getTopLeft(textFinder).dx;

    // A rightward drag must be left for the system back-swipe / other
    // gestures — it must not slide the transcript.
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(_listViewKey)));
    await gesture.moveBy(const Offset(160, 0));
    await tester.pump();

    expect(tester.getTopLeft(textFinder).dx, restX, reason: "rightward drag must not open the timestamp gutter");

    await gesture.moveBy(const Offset(0, 300));
    await tester.pump();

    expect(_position(tester).pixels, greaterThan(20));
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets("a mouse click-and-drag does not peek (left free for text selection)", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final created = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: [
          for (var i = 0; i < 12; i++)
            _message(
              messageId: "u$i",
              role: "user",
              text: _multilineText(label: "Message $i", lines: 6),
              createdAtMs: created,
            ),
        ],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    final textFinder = find.textContaining("Message 11").first;
    final restX = tester.getTopLeft(textFinder).dx;

    // A mouse press-and-drag is the text-selection gesture; it must NOT
    // slide the transcript, or selecting message text becomes impossible.
    // Gated by pointer device kind, so this holds on every platform.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_listViewKey)),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();

    expect(tester.getTopLeft(textFinder).dx, restX, reason: "mouse click-drag must not open the gutter");

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets("a horizontal trackpad pan peeks timestamps without scrolling", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final created = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: [
          for (var i = 0; i < 12; i++)
            _message(
              messageId: "u$i",
              role: "user",
              text: _multilineText(label: "Message $i", lines: 6),
              createdAtMs: created,
            ),
        ],
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    final textFinder = find.textContaining("Message 11").first;
    final restX = tester.getTopLeft(textFinder).dx;
    final restPixels = _position(tester).pixels;

    // A horizontal two-finger trackpad swipe (pan-zoom) is the trackpad
    // peek gesture — it slides the content left without scrolling the
    // list or detaching follow mode.
    final center = tester.getCenter(find.byKey(_listViewKey));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await gesture.panZoomStart(center);
    await gesture.panZoomUpdate(center, pan: const Offset(-160, 0));
    await tester.pump();

    expect(
      tester.getTopLeft(textFinder).dx,
      lessThan(restX),
      reason: "horizontal trackpad pan should slide the content to expose the timestamp",
    );
    expect(_position(tester).pixels, restPixels, reason: "horizontal peek must not scroll the list");
    expect(find.byKey(_jumpToLatestKey), findsNothing, reason: "horizontal peek must not detach follow mode");

    await gesture.panZoomEnd();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(textFinder).dx, closeTo(restX, 0.5));
  });
}
