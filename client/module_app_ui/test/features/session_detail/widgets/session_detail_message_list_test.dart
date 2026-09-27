import "dart:async";
import "dart:convert";

import "package:clock/clock.dart";
import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_jump_notifier.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_prompt_slot.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_sticky_layout.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_sticky_prompt_overlay.dart";
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
  final double topInset = 0,
  final SessionLaunchHandoff? launchHandoff,
}) extends StatefulWidget {
  @override
  State<_SessionDetailMessageListHarness> createState() => _SessionDetailMessageListHarnessState();
}

class _SessionDetailMessageListHarnessState() extends State<_SessionDetailMessageListHarness> {
  late List<MessageWithParts> _messages;
  late Map<String, String> _streamingText;
  late List<QueuedSessionSubmission> _queuedMessages;
  late List<QueuedSessionPrompt> _bridgeQueuedPrompts;
  LocalSendPhase _localSend = const LocalSendPhase.idle();
  int retriedFailedSends = 0;
  List<QueuedSessionSubmission> _awaitingBridgeSubmissions = const [];
  Map<String, List<ComposerAttachment>> _bridgePromptAttachments = const {};
  final List<String> cancelledBridgePromptIds = [];
  late String? _retryErrorMessage;
  bool _isBusy = false;
  bool _mainAgentRunning = false;
  List<Session> _children = const [];
  Map<String, SessionStatus> _childStatuses = const {};
  bool _isLoadingOlderMessages = false;
  bool _hasOlderMessages = true;
  bool _isRefreshing = false;
  int? lastCancelledQueuedMessageIndex;

  /// The focal points of the pinches in that asked for the Prompts screen.
  final List<Offset> pinchIns = [];

  final currentPromptId = ValueNotifier<String?>(null);
  final jumpNotifier = TranscriptJumpNotifier();

  @override
  void dispose() {
    currentPromptId.dispose();
    jumpNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _messages = widget.initialMessages;
    _streamingText = widget.initialStreamingText;
    _queuedMessages = widget.initialQueuedMessages;
    _bridgeQueuedPrompts = widget.initialBridgeQueuedPrompts;
    _retryErrorMessage = widget.initialRetryErrorMessage;
    _launchHandoff = widget.launchHandoff;
  }

  late SessionLaunchHandoff? _launchHandoff;

  /// The first message's echo arrives and releases the launch bubble in the
  /// same build, as the detail cubit emits it.
  void echoLaunch(MessageWithParts message) {
    setState(() {
      _messages = [..._messages, message];
      _launchHandoff = null;
    });
  }

  void startLoadingOlderMessages() {
    setState(() => _isLoadingOlderMessages = true);
  }

  void finishLoadingOlderMessages() {
    setState(() => _isLoadingOlderMessages = false);
  }

  void prependOlderMessages({required List<MessageWithParts> older, required bool hasOlderMessages}) {
    setState(() {
      _messages = [...older, ..._messages];
      _isLoadingOlderMessages = false;
      _hasOlderMessages = hasOlderMessages;
    });
  }

  void appendNewestMessage(MessageWithParts message) {
    setState(() => _messages = [..._messages, message]);
  }

  void removeMessage(String messageId) {
    setState(() => _messages = [..._messages.where((m) => m.info.id != messageId)]);
  }

  void replaceMessages(List<MessageWithParts> messages) {
    setState(() => _messages = messages);
  }

  void updateStreamingText({required String partId, required String text}) {
    setState(() => _streamingText = {..._streamingText, partId: text});
  }

  void setBusy(bool isBusy) {
    setState(() => _isBusy = isBusy);
  }

  void setMainAgentRunning(bool running) {
    setState(() => _mainAgentRunning = running);
  }

  void setChildren({required List<Session> children, required Map<String, SessionStatus> childStatuses}) {
    setState(() {
      _children = children;
      _childStatuses = childStatuses;
    });
  }

  void clearStreamingText() {
    setState(() => _streamingText = const {});
  }

  void setRetryErrorMessage(String? message) {
    setState(() => _retryErrorMessage = message);
  }

  void setRefreshing({required bool refreshing}) {
    setState(() => _isRefreshing = refreshing);
  }

  void cancelQueuedMessage(int index) {
    lastCancelledQueuedMessageIndex = index;
    setState(() => _queuedMessages = [..._queuedMessages]..removeAt(index));
  }

  void enqueueSubmission(QueuedSessionSubmission submission) {
    setState(() => _queuedMessages = [..._queuedMessages, submission]);
  }

  void sendDirectly(QueuedSessionSubmission submission) {
    setState(() => _localSend = LocalSendPhase.sending(submission: submission));
  }

  void beginSending() {
    setState(() {
      _localSend = LocalSendPhase.sending(submission: _queuedMessages.first);
      _queuedMessages = _queuedMessages.sublist(1);
    });
  }

  void failSending() {
    if (_localSend case LocalSendSending(:final submission)) {
      setState(() => _localSend = LocalSendPhase.failed(submission: submission, failure: PromptSendFailure.rejected));
    }
  }

  void acceptSendingSubmission() {
    if (_localSend case LocalSendSending(:final submission)) {
      setState(() {
        _awaitingBridgeSubmissions = [..._awaitingBridgeSubmissions, submission];
        _localSend = const LocalSendPhase.idle();
      });
    }
  }

  void updateBridgeQueue({
    required List<QueuedSessionPrompt> prompts,
    required Map<String, List<ComposerAttachment>> attachments,
  }) {
    setState(() {
      _bridgeQueuedPrompts = prompts;
      _bridgePromptAttachments = attachments;
      final bridgeIds = prompts.map((prompt) => prompt.id).toSet();
      _queuedMessages = _queuedMessages.where((submission) => !bridgeIds.contains(submission.promptId)).toList();
      _awaitingBridgeSubmissions = _awaitingBridgeSubmissions
          .where((submission) => !bridgeIds.contains(submission.promptId))
          .toList();
      if (_localSend case LocalSendSending(:final submission) when bridgeIds.contains(submission.promptId)) {
        _localSend = const LocalSendPhase.idle();
      }
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
          bridgePromptAttachments: _bridgePromptAttachments,
          onCancelBridgeQueuedPrompt: (promptId) {
            cancelledBridgePromptIds.add(promptId);
            setState(
              () => _bridgeQueuedPrompts = [..._bridgeQueuedPrompts.where((prompt) => prompt.id != promptId)],
            );
          },
          projectId: null,
          onLoadOlderMessages: _hasOlderMessages ? widget.onLoadOlderMessages : null,
          messages: _messages,
          localSend: _localSend,
          harnessName: "OpenCode",
          launchHandoff: _launchHandoff,
          onRetryFailedSend: () {
            if (_localSend case LocalSendFailed(:final submission)) {
              setState(() {
                retriedFailedSends++;
                _localSend = LocalSendPhase.sending(submission: submission);
              });
            }
          },
          onRemoveFailedSend: () => setState(() => _localSend = const LocalSendPhase.idle()),
          awaitingBridgeSubmissions: _awaitingBridgeSubmissions,
          queuedMessages: _queuedMessages,
          isLoadingOlderMessages: _isLoadingOlderMessages,
          isRefreshing: _isRefreshing,
          currentPromptId: currentPromptId,
          jumpNotifier: jumpNotifier,
          onPinchIn: ({required focalPoint}) => pinchIns.add(focalPoint),
          topInset: widget.topInset,
          streamingText: _streamingText,
          children: _children,
          childStatuses: _childStatuses,
          isBusy: _isBusy,
          mainAgentRunning: _mainAgentRunning,
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

/// [count] one-line user messages, ids prefixed by [prefix].
List<MessageWithParts> _page({required String prefix, required int count}) => [
  for (var index = 0; index < count; index++)
    _message(messageId: "$prefix-$index", role: "user", text: "$prefix message $index"),
];

String _multilineText({required String label, required int lines}) {
  return List.generate(lines, (index) => "$label line $index").join("\n");
}

/// Eight tall turns, with the prompt of turn [id] replaced by [text].
List<MessageWithParts> _turnsWithPrompt({required String id, required String text}) => [
  for (final message in _turns(count: 8, promptLines: 40, answers: 4, paragraphs: 24))
    if (message.info.id == id) _message(messageId: id, role: "user", text: text) else message,
];

/// A prompt whose blocks each render taller than a line of body text.
const _markdownPrompt = '''
**Refactor** the parser

| field | type |
|---|---|
| id | String |
| name | String |

```dart
void main() {
  print("parsed");
}
```

![diagram](https://example.com/diagram.png)
''';

/// A prompt that is one short fenced code block.
const _fencedPrompt = '''
```dart
void main() {}
```
''';

/// A prompt whose words carry Markdown syntax around them.
const _decoratedPrompt = "Fix **bold** and `code` in [the spec](https://example.com/spec)";

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

const _topInset = 40.0;

/// [count] turns, each a prompt of [promptLines] lines answered by [answers]
/// messages of [paragraphs] paragraphs.
List<MessageWithParts> _turns({
  required int count,
  required int promptLines,
  required int answers,
  required int paragraphs,
}) => [
  for (var turn = 0; turn < count; turn++) ...[
    _message(
      messageId: "u$turn",
      role: "user",
      text: _multilineText(label: "Prompt $turn", lines: promptLines),
    ),
    for (var answer = 0; answer < answers; answer++)
      _message(
        messageId: "a$turn-$answer",
        role: "assistant",
        text: List.generate(paragraphs, (index) => "Answer $turn.$answer, paragraph $index").join("\n\n"),
      ),
  ],
];

Future<_SessionDetailMessageListHarnessState> _pumpTurns(
  WidgetTester tester, {
  required List<MessageWithParts> messages,
}) async {
  await tester.pumpWidget(
    _SessionDetailMessageListHarness(initialMessages: messages, initialStreamingText: const {}, topInset: _topInset),
  );
  await tester.pumpAndSettle();
  return tester.state<_SessionDetailMessageListHarnessState>(find.byType(_SessionDetailMessageListHarness));
}

double _topOf(WidgetTester tester, String rowId) => tester.getTopLeft(_messageKey(rowId)).dy;

/// Every scroll offset the list takes from now on.
List<double> _recordMoves(WidgetTester tester) {
  final position = _position(tester);
  final moves = <double>[];
  position.addListener(() => moves.add(position.pixels));
  return moves;
}

/// Scrolls up to the older row [rowId], less than a viewport at a time, and
/// rests its top at [top]. Scrolling away from the latest edge detaches.
Future<void> _scrollRowTo(WidgetTester tester, {required String rowId, required double top}) async {
  final position = _position(tester);
  while (_messageKey(rowId).evaluate().isEmpty) {
    position.jumpTo(position.pixels + 500);
    await tester.pump();
  }
  position.jumpTo(position.pixels + top - _topOf(tester, rowId));
  await tester.pumpAndSettle();
  expect(find.byKey(_jumpToLatestKey), findsOneWidget);
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

const _pinchPlatforms = TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android, TargetPlatform.macOS});

/// Two fingers land [from] px apart across [center] along [axis] and spread to
/// [to] px apart. With [stillFinger], the first finger holds still and the
/// second travels the whole change.
Future<void> _touchPinch(
  WidgetTester tester, {
  required Offset center,
  required double from,
  required double to,
  Offset axis = const Offset(1, 0),
  bool stillFinger = false,
}) async {
  final first = await tester.startGesture(center - axis * (from / 2));
  final second = await tester.startGesture(center + axis * (from / 2));
  for (var step = 1; step <= 5; step++) {
    final gap = from + (to - from) * step / 5;
    if (!stillFinger) await first.moveTo(center - axis * (gap / 2));
    await second.moveTo(center - axis * (from / 2) + axis * (stillFinger ? gap : gap / 2 + from / 2));
    await tester.pump();
  }
  await first.up();
  await second.up();
  await tester.pumpAndSettle();
}

/// A trackpad pinch at [center] that scales to [scale].
Future<void> _trackpadPinch(WidgetTester tester, {required Offset center, required double scale}) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.trackpad);
  await gesture.panZoomStart(center);
  for (var step = 1; step <= 5; step++) {
    await gesture.panZoomUpdate(center, scale: 1 + (scale - 1) * step / 5);
    await tester.pump();
  }
  await gesture.panZoomEnd();
  await tester.pumpAndSettle();
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

  for (final text in ["Review these images", ""]) {
    testWidgets("keeps local thumbnails through bridge sending with ${text.isEmpty ? 'no text' : 'text'}", (
      tester,
    ) async {
      final attachments = [
        for (var i = 0; i < 2; i++)
          ComposerAttachment(
            mime: "image/png",
            bytes: base64Decode(
              "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
            ),
            filename: "Fixture $i.png",
          ),
      ];
      final submission = QueuedSessionSubmission.text(
        promptId: "image-prompt",
        text: text,
        inputMode: ComposerInputMode.typed,
        attachments: attachments,
        agent: null,
        agentModel: null,
        fastMode: false,
      );
      final prompt = QueuedSessionPrompt(
        id: submission.promptId,
        text: submission.displayText,
        command: null,
        attachmentCount: attachments.length,
        createdAt: 100,
      );
      final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
      await tester.pumpWidget(
        _SessionDetailMessageListHarness(
          key: harnessKey,
          initialMessages: const [],
          initialStreamingText: const {},
          initialQueuedMessages: [submission],
        ),
      );
      await tester.pumpAndSettle();

      void expectThumbnails() {
        final previews = tester.widgetList<Image>(find.byType(Image)).toList();
        expect(previews, hasLength(attachments.length));
        for (var i = 0; i < previews.length; i++) {
          final provider = previews[i].image as ResizeImage;
          expect((provider.imageProvider as MemoryImage).bytes, same(attachments[i].bytes));
        }
        expect(tester.takeException(), isNull);
      }

      expectThumbnails();
      harnessKey.currentState!.beginSending();
      await tester.pump();
      expect(find.text("Sending"), findsOneWidget);
      expectThumbnails();

      harnessKey.currentState!.acceptSendingSubmission();
      await tester.pumpAndSettle();
      expectThumbnails();

      harnessKey.currentState!.updateBridgeQueue(prompts: [prompt], attachments: {submission.promptId: attachments});
      await tester.pumpAndSettle();
      expectThumbnails();

      harnessKey.currentState!.updateBridgeQueue(
        prompts: [prompt.copyWith(dispatchState: QueuedPromptDispatchState.dispatched)],
        attachments: {submission.promptId: attachments},
      );
      await tester.pump();
      expectThumbnails();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("Sending"), findsOneWidget);
      expectThumbnails();
      expect(find.byType(QueuedMessageBubble), findsOneWidget);

      harnessKey.currentState!.deliverBridgePrompt(
        promptId: submission.promptId,
        message: _message(
          messageId: "delivered-image-prompt",
          role: "user",
          text: "Delivered prompt",
          promptId: submission.promptId,
        ),
        insertionIndex: 0,
      );
      await tester.pumpAndSettle();
      expect(find.byType(QueuedMessageBubble), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.text("Delivered prompt"), findsOneWidget);
    });
  }

  testWidgets("coalesced handoff and scrolling keep previews while absent preview data falls back to counts", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final attachment = ComposerAttachment(
      mime: "image/png",
      bytes: base64Decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
      ),
      filename: "Fixture.png",
    );
    final submission = QueuedSessionSubmission.text(
      promptId: "image-prompt",
      text: "Review this image",
      inputMode: ComposerInputMode.typed,
      attachments: [attachment],
      agent: null,
      agentModel: null,
      fastMode: false,
    );
    const prompt = QueuedSessionPrompt(
      id: "image-prompt",
      text: "Review this image",
      command: null,
      attachmentCount: 1,
      createdAt: 100,
      dispatchState: QueuedPromptDispatchState.dispatched,
    );
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 30),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();
    harnessKey.currentState!.sendDirectly(submission);
    // No pump: a fast bridge handoff can coalesce both local states away.
    harnessKey.currentState!.updateBridgeQueue(
      prompts: [prompt],
      attachments: {
        submission.promptId: [attachment],
      },
    );
    await _pumpListUpdate(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(Image), findsOneWidget);

    await _sendPointerScroll(tester: tester, target: find.byKey(_listViewKey), delta: const Offset(0, -1600));
    await _pumpListUpdate(tester);
    expect(_position(tester).pixels, greaterThan(1000));
    expect(find.byType(QueuedMessageBubble), findsNothing);
    await tester.tap(find.byKey(_jumpToLatestKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.widget<QueuedMessageBubble>(find.byType(QueuedMessageBubble)).localAttachments.single,
      same(attachment),
    );

    // The bounded owner may evict an older preview while its row is pending.
    harnessKey.currentState!.updateBridgeQueue(prompts: [prompt], attachments: const {});
    await _pumpListUpdate(tester);
    expect(find.text("Sending"), findsOneWidget);
    expect(find.text("1 image"), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
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
            fastMode: false,
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

  testWidgets("a failed send shows Couldn't send with Retry while later messages stay queued", (tester) async {
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: const [],
        initialStreamingText: const {},
        initialQueuedMessages: [
          _textSubmission(promptId: "prm_failed", text: "first"),
          _textSubmission(promptId: "prm_later", text: "second"),
        ],
      ),
    );
    await tester.pumpAndSettle();
    harnessKey.currentState!.beginSending();
    await tester.pump();
    harnessKey.currentState!.failSending();
    await tester.pumpAndSettle();

    expect(find.text("Couldn’t send"), findsOneWidget);
    expect(find.text("Queued"), findsOneWidget);
    expect(find.widgetWithText(TextButton, "Remove"), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, "Retry"));
    await tester.pumpAndSettle();

    expect(harnessKey.currentState!.retriedFailedSends, 1);
    expect(find.text("Couldn’t send"), findsNothing);
    expect(find.text("Sending"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group("in a narrow pane at large text", () {
    Future<void> pumpNarrowBubble(
      WidgetTester tester, {
      required QueuedMessageBubblePresentation presentation,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                width: 280,
                child: QueuedMessageBubble(
                  displayText: "first",
                  isCommand: false,
                  attachmentCount: 0,
                  localAttachments: const [],
                  presentation: presentation,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets("a failed send's actions wrap instead of overflowing", (tester) async {
      var retries = 0;
      var removals = 0;
      await pumpNarrowBubble(
        tester,
        presentation: QueuedMessageBubblePresentation.failed(
          onRetry: () => retries++,
          onRemove: () => removals++,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, "Retry"));
      await tester.tap(find.widgetWithText(TextButton, "Remove"));
      expect(retries, 1);
      expect(removals, 1);
    });

    testWidgets("a slow send's harness label wraps instead of overflowing", (tester) async {
      const harnessName = "A Very Long Custom Harness Name";
      await pumpNarrowBubble(
        tester,
        presentation: const QueuedMessageBubblePresentation.sending(harnessName: harnessName, sendingSince: null),
      );
      await tester.pump(const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
      expect(find.text("Sending to $harnessName…"), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets("a slow send names the harness after a short delay", (tester) async {
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: const [],
        initialStreamingText: const {},
        initialQueuedMessages: [_textSubmission(promptId: "prm_slow", text: "slow")],
      ),
    );
    await tester.pumpAndSettle();
    harnessKey.currentState!.beginSending();
    await tester.pump();

    expect(find.text("Sending"), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.text("Sending to OpenCode…"), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text("Sending"), findsNothing);
    expect(find.text("Sending to OpenCode…"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("a launch's first message keeps its slow-send copy when the transcript takes it over", (tester) async {
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: const [],
        initialStreamingText: const {},
        launchHandoff: SessionLaunchHandoff(
          submission: NewSessionSubmissionSnapshot.text(
            draft: ComposerDraft.typed(text: "first message"),
            attachments: const [],
          ),
          pluginId: "claude",
          startedAt: clock.now().subtract(const Duration(seconds: 3)),
          followUpIds: const {},
        ),
      ),
    );

    expect(find.text("first message"), findsOneWidget);
    // Named from the launch's plugin, not the list's harness name, so it
    // reads as the new-session screen's bubble did.
    expect(find.text("Sending to Claude Code…"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("a launch's first message turns into its echo in place, above the working row", (tester) async {
    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: const [],
        initialStreamingText: const {},
        launchHandoff: SessionLaunchHandoff(
          submission: NewSessionSubmissionSnapshot.text(
            draft: ComposerDraft.typed(text: "first message"),
            attachments: const [],
          ),
          pluginId: "claude",
          startedAt: clock.now(),
          followUpIds: const {},
        ),
      ),
    );
    harnessKey.currentState!.setBusy(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final promptRow = find.ancestor(of: find.text("first message"), matching: find.byType(AnimatedSize));
    final before = tester.state(promptRow);
    expect(
      tester.getTopLeft(find.text("first message")).dy,
      lessThan(tester.getTopLeft(find.byType(TranscriptWorkingRow)).dy),
    );

    harnessKey.currentState!.echoLaunch(_message(messageId: "user-1", role: "user", text: "first message"));
    await tester.pump();

    // The bubble's row eases into the echo's instead of remounting elsewhere.
    expect(tester.state(promptRow), same(before));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(QueuedMessageBubble), findsNothing);
    expect(find.byType(UserMessageCard), findsOneWidget);
    expect(
      tester.getTopLeft(find.text("first message")).dy,
      lessThan(tester.getTopLeft(find.byType(TranscriptWorkingRow)).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
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
      hasOlderMessages: true,
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
      hasOlderMessages: true,
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
        // The page stays on its way, as a real one does across the next frames.
        onLoadOlderMessages: () {
          requested++;
          return Completer<void>().future;
        },
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

    // An instant failure can be asked again by each scroll frame near the edge.
    expect(requested, greaterThan(1));
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

  group("a transcript shorter than the screen", () {
    testWidgets("pages back without a scroll until it fills the screen", (tester) async {
      final key = GlobalKey<_SessionDetailMessageListHarnessState>();
      var requested = 0;
      await tester.pumpWidget(
        _SessionDetailMessageListHarness(
          key: key,
          initialMessages: _page(prefix: "newest", count: 2),
          initialStreamingText: const {},
          onLoadOlderMessages: () async {
            requested++;
            key.currentState?.prependOlderMessages(
              older: _page(prefix: "page$requested", count: 2),
              hasOlderMessages: true,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(requested, greaterThan(1), reason: "each page still too short must ask for the next one");
      expect(requested, lessThan(20), reason: "paging must stop once the screen is filled");
      expect(_position(tester).maxScrollExtent, greaterThan(0));
    });

    testWidgets("stops when no older page remains, even if pages add no visible rows", (tester) async {
      final key = GlobalKey<_SessionDetailMessageListHarnessState>();
      var requested = 0;
      await tester.pumpWidget(
        _SessionDetailMessageListHarness(
          key: key,
          initialMessages: _page(prefix: "newest", count: 2),
          initialStreamingText: const {},
          onLoadOlderMessages: () async {
            requested++;
            key.currentState?.prependOlderMessages(
              older: [
                MessageWithParts(
                  info: Message.user(
                    promptId: null,
                    id: "hidden-$requested",
                    sessionID: "session-1",
                    agent: null,
                    time: null,
                  ),
                  parts: const [],
                ),
              ],
              hasOlderMessages: requested < 3,
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(requested, 3);
    });

    testWidgets("asks for no older page while one is on its way", (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final key = GlobalKey<_SessionDetailMessageListHarnessState>();
      final pages = <Completer<void>>[];
      await tester.pumpWidget(
        _SessionDetailMessageListHarness(
          key: key,
          initialMessages: _page(prefix: "newest", count: 2),
          initialStreamingText: const {},
          onLoadOlderMessages: () {
            final page = Completer<void>();
            pages.add(page);
            return page.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(pages, hasLength(1));

      // A taller window and a new oldest message would each ask again.
      await tester.binding.setSurfaceSize(const Size(800, 700));
      key.currentState?.replaceMessages([
        _message(messageId: "earlier", role: "user", text: "earlier"),
        ..._page(prefix: "newest", count: 2),
      ]);
      await tester.pumpAndSettle();
      expect(pages, hasLength(1));

      // The page lands with its load, still too short, so the next one follows.
      key.currentState?.prependOlderMessages(older: _page(prefix: "older", count: 2), hasOlderMessages: true);
      pages.single.complete();
      await tester.pumpAndSettle();
      expect(pages, hasLength(2));
    });

    testWidgets("asks again when a refresh ends, for a page the refresh dropped", (tester) async {
      final key = GlobalKey<_SessionDetailMessageListHarnessState>();
      var requested = 0;
      await tester.pumpWidget(
        _SessionDetailMessageListHarness(
          key: key,
          initialMessages: _page(prefix: "newest", count: 2),
          initialStreamingText: const {},
          // The cubit ignores a request while a refresh runs.
          onLoadOlderMessages: () async => requested++,
        ),
      );
      key.currentState?.setRefreshing(refreshing: true);
      await tester.pumpAndSettle();
      expect(requested, 1);

      // The refresh lands on the same newest page.
      key.currentState?.replaceMessages(_page(prefix: "newest", count: 2));
      key.currentState?.setRefreshing(refreshing: false);
      await tester.pumpAndSettle();
      expect(requested, 2);
    });

    testWidgets("asks again once a page the refresh discarded settles", (tester) async {
      final key = GlobalKey<_SessionDetailMessageListHarnessState>();
      final pages = <Completer<void>>[];
      await tester.pumpWidget(
        _SessionDetailMessageListHarness(
          key: key,
          initialMessages: _page(prefix: "newest", count: 2),
          initialStreamingText: const {},
          onLoadOlderMessages: () {
            final page = Completer<void>();
            pages.add(page);
            return page.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(pages, hasLength(1));

      key.currentState?.setRefreshing(refreshing: true);
      await tester.pump();
      key.currentState?.setRefreshing(refreshing: false);
      await tester.pumpAndSettle();
      expect(pages, hasLength(1));

      // The discarded page returns after the refresh landed.
      pages.single.complete();
      await tester.pumpAndSettle();
      expect(pages, hasLength(2));
    });

    testWidgets("asks for a failed page again on the next scroll, not in a loop", (tester) async {
      final key = GlobalKey<_SessionDetailMessageListHarnessState>();
      final pages = <Completer<void>>[];
      await tester.pumpWidget(
        _SessionDetailMessageListHarness(
          key: key,
          initialMessages: _page(prefix: "newest", count: 2),
          initialStreamingText: const {},
          onLoadOlderMessages: () {
            key.currentState?.startLoadingOlderMessages();
            final page = Completer<void>();
            pages.add(page);
            return page.future;
          },
        ),
      );
      await tester.pump();
      expect(pages, hasLength(1));

      // The bridge fails the page: the cursor stays and loading stops.
      key.currentState?.finishLoadingOlderMessages();
      pages.single.complete();
      await tester.pumpAndSettle();
      expect(pages, hasLength(1));

      await tester.drag(find.byType(SessionDetailMessageList), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(pages, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets("a transcript that shrinks below the screen without a scroll loads the older page", (tester) async {
    final key = GlobalKey<_SessionDetailMessageListHarnessState>();
    var requested = 0;
    final messages = _turns(count: 3, promptLines: 1, answers: 4, paragraphs: 4);
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: key,
        initialMessages: messages,
        initialStreamingText: const {},
        onLoadOlderMessages: () {
          requested++;
          return Completer<void>().future;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(requested, 0);

    // The oldest message stays, so only the shorter layout can ask for the page.
    key.currentState?.replaceMessages(messages.take(2).toList());
    await tester.pumpAndSettle();
    expect(requested, 1);
  });

  testWidgets("a taller window loads the older page", (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requested = 0;
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        initialMessages: _userMessages(count: 6),
        initialStreamingText: const {},
        onLoadOlderMessages: () {
          requested++;
          return Completer<void>().future;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(requested, 0);

    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpAndSettle();
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

  testWidgets("the jump button keeps its constant label whatever the session runs", (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    MessageWithParts toolMessage({required String id, required ToolStatus status}) => MessageWithParts(
      info: Message.assistant(
        id: id,
        sessionID: "session-1",
        agent: null,
        modelID: null,
        providerID: null,
        time: null,
      ),
      parts: [
        MessagePart.tool(
          id: "$id-tool",
          sessionID: "session-1",
          messageID: id,
          tool: "bash",
          state: ToolState(status: status, title: null, shellCommand: "make check", output: null, error: null),
        ),
      ],
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
    expect(find.text("Jump to latest"), findsOneWidget);

    harnessKey.currentState!.appendNewestMessage(toolMessage(id: "run-1", status: ToolStatus.running));
    await _pumpListUpdate(tester);
    final pill = find.byKey(_jumpToLatestKey);
    expect(find.descendant(of: pill, matching: find.text("Jump to latest")), findsOneWidget);
    expect(find.descendant(of: pill, matching: find.byType(PregoShimmer)), findsNothing);

    harnessKey.currentState!.removeMessage("run-1");
    harnessKey.currentState!.appendNewestMessage(toolMessage(id: "queued", status: ToolStatus.pending));
    await _pumpListUpdate(tester);
    expect(find.descendant(of: pill, matching: find.text("Jump to latest")), findsOneWidget);

    harnessKey.currentState!.removeMessage("queued");
    harnessKey.currentState!.appendNewestMessage(toolMessage(id: "run-2", status: ToolStatus.completed));
    await _pumpListUpdate(tester);
    expect(find.descendant(of: pill, matching: find.text("Jump to latest")), findsOneWidget);
    expect(find.descendant(of: pill, matching: find.byType(PregoShimmer)), findsNothing);
  });

  testWidgets("a busy session with no live step or streaming text ends in a Working row that a live step replaces", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    MessageWithParts toolMessage({required ToolStatus status}) => MessageWithParts(
      info: const Message.assistant(
        id: "assistant-1",
        sessionID: "session-1",
        agent: null,
        modelID: null,
        providerID: null,
        time: null,
      ),
      parts: [
        MessagePart.tool(
          id: "assistant-1-tool",
          sessionID: "session-1",
          messageID: "assistant-1",
          tool: "read",
          state: ToolState(status: status, title: "notes.md", shellCommand: null, output: null, error: null),
        ),
      ],
    );
    // The first frame starts the row's ease in or out; the second ends it.
    Future<void> settle() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // The sparkle leads its row's label.
    void expectSparkleLeads(Finder label) {
      final row = find.ancestor(of: label, matching: find.byType(Row)).first;
      final sparkle = find.descendant(of: row, matching: find.byType(PregoAiLoader));
      expect(sparkle, findsOneWidget);
      expect(tester.getTopLeft(sparkle).dx, lessThan(tester.getTopLeft(label).dx));
    }

    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 2),
        initialStreamingText: const {},
      ),
    );
    await settle();
    expect(find.text("Working…"), findsNothing);

    harnessKey.currentState!.setBusy(true);
    await settle();
    expect(find.text("Working…"), findsOneWidget);
    expectSparkleLeads(find.text("Working…"));

    harnessKey.currentState!.appendNewestMessage(toolMessage(status: ToolStatus.running));
    await settle();
    expect(find.text("Working…"), findsNothing);
    expectSparkleLeads(find.text("Read notes.md"));

    harnessKey.currentState!
      ..removeMessage("assistant-1")
      ..appendNewestMessage(toolMessage(status: ToolStatus.completed));
    await settle();
    expect(find.text("Working…"), findsOneWidget);

    // Streaming text already shows progress.
    harnessKey.currentState!.updateStreamingText(partId: "assistant-1-text", text: "Reading the");
    await settle();
    expect(find.text("Working…"), findsNothing);

    harnessKey.currentState!.clearStreamingText();
    await settle();
    expect(find.text("Working…"), findsOneWidget);

    harnessKey.currentState!.setBusy(false);
    await settle();
    expect(find.text("Working…"), findsNothing);

    // A retry row already says the session works.
    harnessKey.currentState!
      ..setBusy(true)
      ..setRetryErrorMessage("Rate limited");
    await settle();
    expect(find.text("Working…"), findsNothing);
  });

  testWidgets("the sub-agent row takes over from Working… with an ease while only sub-agents run", (tester) async {
    await withClock(Clock(() => tester.binding.clock.now()), () async {
      final harness = await _pumpTurns(
        tester,
        messages: _turns(count: 1, promptLines: 1, answers: 1, paragraphs: 1),
      );
      harness.setBusy(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("Working…"), findsOneWidget);

      final startedAt = tester.binding.clock.now().millisecondsSinceEpoch - 185000;
      final child = Session(
        approvalOverride: null,
        id: "child-1",
        projectID: "p",
        directory: "/d",
        parentID: "session-1",
        title: "Explore",
        time: SessionTime(created: startedAt, updated: startedAt, archived: null),
        pullRequest: null,
        promptDefaults: null,
        branchName: null,
        lastUserActivityAt: null,
        autoContinuation: null,
      );
      harness.setChildren(children: [child], childStatuses: const {"child-1": SessionStatus.busy()});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-ease both rows show: Working… folds away as the sub-agent row grows in.
      expect(find.text("Working…"), findsOneWidget);
      expect(find.text("You can keep chatting meanwhile."), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text("Working…"), findsNothing);
      expect(find.text("1 sub-agent running in the background · "), findsOneWidget);
      expect(find.text("3m 05s"), findsOneWidget);
      expect(find.byType(PregoActivityIndicator), findsOneWidget);
      expect(find.byType(PregoAiLoader), findsNothing);

      // The main agent back mid-turn, or blocked on a foreground sub-agent:
      // a new prompt would wait, so the row gives way to Working….
      harness.setMainAgentRunning(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("You can keep chatting meanwhile."), findsNothing);
      expect(find.text("Working…"), findsOneWidget);
      harness.setMainAgentRunning(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("You can keep chatting meanwhile."), findsOneWidget);

      // A question or permission clears isBusy, and with it the row.
      harness.setBusy(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("You can keep chatting meanwhile."), findsNothing);

      harness
        ..setBusy(true)
        ..setChildren(children: [child], childStatuses: const {"child-1": SessionStatus.idle()});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text("Working…"), findsOneWidget);
    });
  });

  testWidgets("a reader pinned at the bottom stays pinned while a finished step folds into its group", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    MessagePart tool({required String id, required ToolStatus status}) => MessagePart.tool(
      id: id,
      sessionID: "session-1",
      messageID: "assistant-1",
      tool: "read",
      state: ToolState(status: status, title: id, shellCommand: null, output: null, error: null),
    );
    MessageWithParts assistant({required ToolStatus last}) => MessageWithParts(
      info: const Message.assistant(
        id: "assistant-1",
        sessionID: "session-1",
        agent: null,
        modelID: null,
        providerID: null,
        time: null,
      ),
      parts: [
        tool(id: "first", status: ToolStatus.completed),
        tool(id: "second", status: last),
      ],
    );

    final harnessKey = GlobalKey<_SessionDetailMessageListHarnessState>();
    await tester.pumpWidget(
      _SessionDetailMessageListHarness(
        key: harnessKey,
        initialMessages: _userMessages(count: 10),
        initialStreamingText: const {},
      ),
    );
    await tester.pumpAndSettle();
    harnessKey.currentState!
      ..setBusy(true)
      ..appendNewestMessage(assistant(last: ToolStatus.running));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("Read second"), findsOneWidget);
    expect(_position(tester).pixels, 0);

    harnessKey.currentState!
      ..removeMessage("assistant-1")
      ..appendNewestMessage(assistant(last: ToolStatus.completed));
    // Every frame of the fold, and of the Working row easing in, keeps the
    // newest edge in view.
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 30));
      expect(_position(tester).pixels, 0);
      expect(find.byKey(_jumpToLatestKey), findsNothing);
    }
    expect(find.text("Read second"), findsNothing);
    expect(find.text("2 steps"), findsOneWidget);
    expect(find.text("Working…"), findsOneWidget);
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
  }, variant: _pinchPlatforms);

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
      fastMode: false,
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
      fastMode: false,
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
      fastMode: false,
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
      fastMode: false,
    );
    const unavailable = QueuedSessionSubmission.unavailableCommand(
      promptId: "prompt-1",
      text: "src",
      command: "review",
      agent: "coder",
      agentModel: null,
      fastMode: false,
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
      fastMode: false,
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
    // The card folds away rather than vanishing in one frame.
    expect(find.byType(RetryErrorMessageCard), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(RetryErrorMessageCard), findsNothing);
    expect(_messageKey("user-2"), findsOneWidget);
  });

  group("a pinch", () {
    final shortTurns = _turns(count: 20, promptLines: 1, answers: 1, paragraphs: 12);
    Offset center(WidgetTester tester) => tester.getCenter(find.byKey(_listViewKey));

    testWidgets("in opens the Prompts screen once, and out does nothing", (tester) async {
      final harness = await _pumpTurns(tester, messages: shortTurns);

      await _touchPinch(tester, center: center(tester), from: 300, to: 40);
      expect(harness.pinchIns, hasLength(1));

      await _touchPinch(tester, center: center(tester), from: 40, to: 300);
      expect(harness.pinchIns, hasLength(1));
      expect(_position(tester).pixels, 0);
    }, variant: _pinchPlatforms);

    testWidgets("with one finger held still opens on a vertical pinch", (tester) async {
      final harness = await _pumpTurns(tester, messages: shortTurns);

      await _touchPinch(
        tester,
        center: center(tester),
        from: 300,
        to: 120,
        axis: const Offset(0, 1),
        stillFinger: true,
      );

      expect(harness.pinchIns, hasLength(1));
      expect(_position(tester).pixels, 0);
    }, variant: _pinchPlatforms);

    testWidgets("on a trackpad opens on a pinch in, not out", (tester) async {
      final harness = await _pumpTurns(tester, messages: shortTurns);

      await _trackpadPinch(tester, center: center(tester), scale: 0.6);
      expect(harness.pinchIns, [center(tester)]);

      await _trackpadPinch(tester, center: center(tester), scale: 1.6);
      expect(harness.pinchIns, hasLength(1));
    }, variant: _pinchPlatforms);

    testWidgets("below the threshold opens, scrolls and detaches nothing", (tester) async {
      final harness = await _pumpTurns(tester, messages: shortTurns);

      await _touchPinch(tester, center: center(tester), from: 200, to: 180, axis: const Offset(0, 1));
      await _trackpadPinch(tester, center: center(tester), scale: 0.9);

      expect(harness.pinchIns, isEmpty);
      expect(_position(tester).pixels, 0);
      expect(find.byKey(_jumpToLatestKey), findsNothing);
    }, variant: _pinchPlatforms);

    testWidgets("while following opens, moves nothing and keeps following", (tester) async {
      final harness = await _pumpTurns(tester, messages: shortTurns);
      final focalPoint = center(tester) + const Offset(-60, 90);

      await _trackpadPinch(tester, center: focalPoint, scale: 0.6);

      expect(harness.pinchIns, [focalPoint]);
      expect(_position(tester).pixels, 0);
      expect(find.byKey(_jumpToLatestKey), findsNothing);
    }, variant: _pinchPlatforms);

    testWidgets("while reading history opens, moves nothing and stays detached", (tester) async {
      final harness = await _pumpTurns(tester, messages: shortTurns);
      await _scrollRowTo(tester, rowId: "u8", top: 300);

      await _touchPinch(
        tester,
        center: Offset(400, tester.getBottomLeft(_messageKey("u8")).dy + 60),
        from: 300,
        to: 40,
      );

      expect(harness.pinchIns, hasLength(1));
      expect(_topOf(tester, "u8"), moreOrLessEquals(300, epsilon: 1));
      expect(find.byKey(_jumpToLatestKey), findsOneWidget);
    }, variant: _pinchPlatforms);

    testWidgets("while reading history near the latest edge stays detached as output arrives", (tester) async {
      final harness = await _pumpTurns(tester, messages: shortTurns);
      await _scrollRowTo(tester, rowId: "a18-0", top: _topInset - 100);
      final pixels = _position(tester).pixels;

      await _touchPinch(tester, center: tester.getCenter(_messageKey("a18-0")), from: 300, to: 40);
      expect(harness.pinchIns, hasLength(1));
      expect(_position(tester).pixels, pixels);

      harness.appendNewestMessage(_message(messageId: "late", role: "assistant", text: "Late output"));
      await tester.pumpAndSettle();

      expect(find.byKey(_jumpToLatestKey), findsOneWidget);
      expect(_messageKey("late"), findsNothing);
    }, variant: _pinchPlatforms);
  });

  group("the pinned prompt", () {
    final shortTurns = _turns(count: 20, promptLines: 1, answers: 1, paragraphs: 12);
    // Every prompt and answer is taller than the viewport.
    final tallTurns = _turns(count: 16, promptLines: 40, answers: 4, paragraphs: 24);
    // Short and long prompts in turn, each answered in less than a viewport.
    final mixedTurns = [
      for (var turn = 0; turn < 8; turn++) ...[
        _message(
          messageId: "u$turn",
          role: "user",
          text: _multilineText(label: "Prompt $turn", lines: turn.isOdd ? 12 : 1),
        ),
        for (var answer = 0; answer < 2; answer++)
          _message(
            messageId: "a$turn-$answer",
            role: "assistant",
            text: List.generate(5, (index) => "Answer $turn.$answer, paragraph $index").join("\n\n"),
          ),
      ],
    ];
    const pinTop = _topInset + 6;
    final overlay = find.byType(TranscriptStickyPromptOverlay);

    RenderTranscriptStickyPrompts pins(WidgetTester tester) => tester.renderObject(overlay);

    TranscriptPinnedPrompt? pinOf(WidgetTester tester, String openerId) =>
        pins(tester).stickyLayout.pinned.where((pin) => pin.openerId == openerId).firstOrNull;

    /// The pinned copy of [openerId]'s bubble content.
    Finder copyOf(String openerId) => find.descendant(
      of: find.descendant(of: overlay, matching: find.byKey(ValueKey((pinnedPrompt: openerId)))),
      matching: find.byType(UserMessageBubbleContent),
    );

    /// Where [openerId]'s pin paints its bubble.
    Rect pinnedBubble(WidgetTester tester, String openerId) {
      final pin = pinOf(tester, openerId) ?? fail("$openerId is not pinned");
      final content = tester.getRect(copyOf(openerId));
      return Rect.fromLTWH(content.left - 10, pin.top, content.width + 20, pin.height);
    }

    Finder slotOf(String openerId) =>
        find.descendant(of: _messageKey(openerId), matching: find.byType(TranscriptPromptSlot));

    /// Where [openerId]'s own bubble is, whether or not it paints.
    Rect ownBubble(WidgetTester tester, String openerId) => tester
        .getRect(find.descendant(of: slotOf(openerId), matching: find.byType(UserMessageBubbleContent)))
        .inflate(10);

    /// The one bubble the reader sees of each of [openerIds], pinned or its own.
    Map<String, Rect> seenBubbles(WidgetTester tester, {required List<String> openerIds, required Rect screen}) {
      final seen = <String, Rect>{};
      for (final openerId in openerIds) {
        final bubbles = [
          if (pinOf(tester, openerId) != null) pinnedBubble(tester, openerId),
          if (slotOf(openerId).evaluate().isNotEmpty &&
              !tester.renderObject<RenderTranscriptPromptSlot>(slotOf(openerId)).hidden)
            ownBubble(tester, openerId),
        ].where((bubble) => bubble.overlaps(screen)).toList();
        expect(bubbles.length, lessThanOrEqualTo(1), reason: "$openerId shows twice: $bubbles");
        if (bubbles.firstOrNull case final bubble?) seen[openerId] = bubble;
      }
      return seen;
    }

    testWidgets("shows one bubble per prompt, moving with the scroll and never against it", (tester) async {
      await _pumpTurns(tester, messages: mixedTurns);
      final openerIds = [for (var turn = 0; turn < 8; turn++) "u$turn"];
      final screen = tester.getRect(find.byKey(_listViewKey));
      final position = _position(tester);
      const step = 7.0;
      final pinnedIds = <String>{};
      // Clear of the latest edge, where the list snaps back to following.
      position.jumpTo(200);
      await tester.pumpAndSettle();

      // Slowly up through several short and long prompts, then back down.
      for (final direction in [1.0, -1.0]) {
        var before = seenBubbles(tester, openerIds: openerIds, screen: screen);
        for (var moved = 0.0; moved < 2400; moved += step) {
          position.jumpTo(position.pixels + direction * step);
          await tester.pump();
          final after = seenBubbles(tester, openerIds: openerIds, screen: screen);
          for (final openerId in {...before.keys, ...after.keys}) {
            final (was, now) = (before[openerId], after[openerId]);
            if (was != null && now != null) {
              // Older rows come down as the list scrolls up to them, a step a
              // frame at most, so a bubble never jumps, pops or backs up.
              final move = (now.top - was.top) * direction;
              expect(move, inInclusiveRange(-0.01, step + 0.01), reason: "$openerId moved $move from $was to $now");
            } else {
              // A bubble only comes and goes across the screen's edges.
              final edge = now ?? was ?? fail("unreachable");
              expect(
                edge.top >= screen.bottom - step - 0.01 || edge.bottom <= screen.top + step + 0.01,
                isTrue,
                reason: "$openerId ${now == null ? "vanished" : "popped in"} at $edge",
              );
            }
          }
          for (final pin in pins(tester).stickyLayout.pinned) {
            pinnedIds.add(pin.openerId);
            final compact = pin.fullHeight < pins(tester).compactHeight ? pin.fullHeight : pins(tester).compactHeight;
            expect(pin.top, lessThanOrEqualTo(pinTop + 0.01));
            expect(pin.height, inInclusiveRange(compact - 0.01, pin.fullHeight + 0.01));
          }
          before = after;
        }
      }
      expect(pinnedIds, containsAll(["u4", "u5", "u6"]), reason: "the sweep must pass short and long prompts");
    });

    testWidgets("takes over from its bubble exactly where the two coincide", (tester) async {
      final semantics = tester.ensureSemantics();
      final spoken = find.bySemanticsLabel(RegExp("Prompt 5 line 0"));
      await _pumpTurns(tester, messages: mixedTurns);
      await _scrollRowTo(tester, rowId: "u5", top: pinTop - PregoSpacing.xs + 1);
      expect(pinOf(tester, "u5"), isNull, reason: "a bubble below the pin line pins nothing");
      expect(tester.renderObject<RenderTranscriptPromptSlot>(slotOf("u5")).hidden, isFalse);
      expect(spoken, findsOneWidget);

      await _scrollRowTo(tester, rowId: "u5", top: pinTop - PregoSpacing.xs);
      expect(spoken, findsOneWidget, reason: "a screen reader meets the prompt once, as the pin");
      semantics.dispose();

      final pin = pinOf(tester, "u5") ?? fail("u5 is not pinned");
      expect(tester.renderObject<RenderTranscriptPromptSlot>(slotOf("u5")).hidden, isTrue);
      final own = ownBubble(tester, "u5");
      final pinned = pinnedBubble(tester, "u5");
      expect(pinned.left, moreOrLessEquals(own.left, epsilon: 0.01));
      expect(pinned.top, moreOrLessEquals(own.top, epsilon: 0.01));
      expect(pinned.width, moreOrLessEquals(own.width, epsilon: 0.01));
      expect(pinned.height, moreOrLessEquals(own.height, epsilon: 0.01));
      expect(pin.elevation, 0, reason: "nothing slides under a pin that is its whole bubble");
    });

    testWidgets("lifts off the rows under it with a halo the pin line does not clip", (tester) async {
      debugDisableShadows = false;
      await _pumpTurns(tester, messages: tallTurns);
      await _scrollRowTo(tester, rowId: "a6-1", top: _topInset - 100);

      final pin = pinOf(tester, "u6") ?? fail("u6 is not pinned");
      expect(pin.elevation, 1);
      // The pins paint from the list's top edge, behind the bar, not from the
      // pin line, so the halo reaches up into the bar's fade.
      expect(tester.getTopLeft(overlay).dy, tester.getTopLeft(find.byKey(_listViewKey)).dy);
      final halo = RRect.fromRectAndRadius(
        pinnedBubble(tester, "u6"),
        const Radius.circular(UserMessageBubble.radius),
      ).inflate(14);
      expect(halo.top, lessThan(pinTop));
      expect(pins(tester), paints..rrect(rrect: halo));
      debugDisableShadows = true;
    });

    testWidgets("compacts a long prompt to a three-line bubble", (tester) async {
      await _pumpTurns(tester, messages: tallTurns);
      await _scrollRowTo(tester, rowId: "a6-1", top: _topInset - 100);

      final long = pinOf(tester, "u6") ?? fail("u6 is not pinned");
      expect(long.top, pinTop);
      expect(long.height, pins(tester).compactHeight);
      expect(long.height, lessThan(long.fullHeight));
    });

    testWidgets("pins a short prompt whole", (tester) async {
      await _pumpTurns(tester, messages: shortTurns);
      await _scrollRowTo(tester, rowId: "a8-0", top: _topInset - 100);

      final short = pinOf(tester, "u8") ?? fail("u8 is not pinned");
      expect(short.height, short.fullHeight);
    });

    /// Expects a 40-line prompt to compact exactly as tall as a prompt of
    /// three short lines, which pins whole, whatever a line measures here.
    Future<void> expectThreeLineCompaction(WidgetTester tester) async {
      await _pumpTurns(
        tester,
        messages: _turnsWithPrompt(id: "u4", text: "A\nB\nC"),
      );
      await _scrollRowTo(tester, rowId: "a4-1", top: _topInset - 100);
      final threeLines = pinOf(tester, "u4") ?? fail("u4 is not pinned");
      expect(threeLines.height, threeLines.fullHeight);

      await _scrollRowTo(tester, rowId: "a3-1", top: _topInset - 100);

      final long = pinOf(tester, "u3") ?? fail("u3 is not pinned");
      expect(long.fullHeight, greaterThan(threeLines.height), reason: "the fixture must compact");
      expect(long.height, moreOrLessEquals(threeLines.height, epsilon: 1));
    }

    testWidgets("compacts to three lines at a narrow width", (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await expectThreeLineCompaction(tester);
    });

    testWidgets("compacts to three lines at a large text scale", (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await expectThreeLineCompaction(tester);
    });

    testWidgets("pins nothing over the messages before the first prompt", (tester) async {
      await _pumpTurns(
        tester,
        messages: [
          _automatedMessage(
            messageId: "setup",
            text: List.generate(40, (index) => "Automation paragraph $index").join("\n\n"),
            sender: MessageSender.system,
          ),
          ...shortTurns,
        ],
      );

      await _scrollRowTo(tester, rowId: "setup", top: _topInset - 300);

      expect(pins(tester).stickyLayout.pinned, isEmpty);
    });

    testWidgets("renders the prompt as its own bubble does", (tester) async {
      await _pumpTurns(
        tester,
        messages: _turnsWithPrompt(id: "u4", text: _markdownPrompt),
      );

      await _scrollRowTo(tester, rowId: "a4-1", top: _topInset - 100);

      expect(pinOf(tester, "u4"), isNotNull);
      expect(find.descendant(of: copyOf("u4"), matching: find.byType(Table)), findsOneWidget);
      expect(find.descendant(of: copyOf("u4"), matching: find.byType(CodeBlock)), findsOneWidget);
      expect(find.descendant(of: copyOf("u4"), matching: find.textContaining("**", findRichText: true)), findsNothing);
    });

    testWidgets("builds only the start of a pasted document", (tester) async {
      await _pumpTurns(
        tester,
        messages: _turnsWithPrompt(
          id: "u4",
          text: _multilineText(label: "Pasted", lines: 2000),
        ),
      );

      await _scrollRowTo(tester, rowId: "a4-1", top: _topInset - 100);

      final built = tester
          .renderObject<RenderParagraph>(find.descendant(of: copyOf("u4"), matching: find.byType(RichText)).first)
          .text
          .toPlainText();
      expect(built, startsWith("Pasted line 0\nPasted line 1\n"));
      expect(built, isNot(contains("Pasted line 1500")));
    });

    testWidgets("pins a fence left open by the cut as a code block, not backticks", (tester) async {
      await _pumpTurns(
        tester,
        messages: _turnsWithPrompt(
          id: "u4",
          text: "```dart\n${_multilineText(label: "// pasted", lines: 1000)}\n```",
        ),
      );

      await _scrollRowTo(tester, rowId: "a4-1", top: _topInset - 100);

      expect(find.descendant(of: copyOf("u4"), matching: find.byType(CodeBlock)), findsOneWidget);
      expect(find.descendant(of: copyOf("u4"), matching: find.textContaining("```", findRichText: true)), findsNothing);
    });

    testWidgets("a pinned code block asks for no older page", (tester) async {
      var requested = 0;
      await tester.pumpWidget(
        _SessionDetailMessageListHarness(
          initialMessages: _turnsWithPrompt(id: "u4", text: _fencedPrompt),
          initialStreamingText: const {},
          topInset: _topInset,
          onLoadOlderMessages: () async => requested++,
        ),
      );
      await tester.pumpAndSettle();

      await _scrollRowTo(tester, rowId: "a4-1", top: _topInset - 100);

      // The pins are the list's sibling, so a scroll view in a copy would
      // report its metrics at depth 0 and the list would read them as its own.
      expect(pinOf(tester, "u4"), isNotNull);
      expect(requested, 0, reason: "the pinned prompt must not page history the reader never asked for");
    });

    testWidgets("labels the pinned bubble with the prompt's words, not its Markdown", (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpTurns(
        tester,
        messages: _turnsWithPrompt(id: "u4", text: _decoratedPrompt),
      );

      await _scrollRowTo(tester, rowId: "a4-1", top: _topInset - 100);

      // The copy is hidden from semantics, so this label is all a screen
      // reader gets; it must not read out markers, backticks and URLs.
      expect(
        tester.getSemantics(copyOf("u4")),
        isSemantics(
          label: "Fix bold and code in the spec",
          hint: "Jump to this prompt",
          isButton: true,
          hasTapAction: true,
        ),
      );

      semantics.dispose();
    });

    testWidgets("reads a pinned list, table and struck word as the row lays them out", (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpTurns(
        tester,
        messages: _turnsWithPrompt(
          id: "u4",
          text: "- Fix login\n- Fix signup\n\n| col |\n| --- |\n| cell |\n\n~~dropped~~",
        ),
      );

      await _scrollRowTo(tester, rowId: "a4-1", top: _topInset - 100);

      // Each item, cell and paragraph has a line of its own in the row, so none
      // of them may run into the next word. And the label is read with the same
      // extensions the row is rendered with, or a table would be spoken as its
      // pipes and a struck word as its tildes.
      expect(
        tester.getSemantics(copyOf("u4")),
        isSemantics(label: "Fix login\nFix signup\ncol\ncell\ndropped", isButton: true),
      );

      semantics.dispose();
    });

    /// Pins a prompt that renders as a single image and checks that a screen
    /// reader hears [words], never the image's source.
    Future<void> expectPinnedImageNamed(WidgetTester tester, {required String prompt, required String words}) async {
      final semantics = tester.ensureSemantics();
      await _pumpTurns(
        tester,
        messages: _turnsWithPrompt(id: "u4", text: prompt),
      );

      await _scrollRowTo(tester, rowId: "a4-1", top: _topInset - 100);

      expect(
        tester.getSemantics(copyOf("u4")),
        isSemantics(label: words, hint: "Jump to this prompt", isButton: true, hasTapAction: true),
      );
      // A prompt can name any host, so pinning it must not contact that host.
      expect(find.descendant(of: copyOf("u4"), matching: find.byType(MarkdownMessageImage)), findsNothing);

      semantics.dispose();
    }

    testWidgets("reads an image-only prompt out as its alt text", (tester) async {
      await expectPinnedImageNamed(tester, prompt: "![diagram](https://example.com/diagram.png)", words: "diagram");
    });

    testWidgets("reads an image-only prompt with no alt text out as the row names it", (tester) async {
      await expectPinnedImageNamed(tester, prompt: "![](https://example.com/diagram.png)", words: "Open image");
    });

    testWidgets("a tap on the bubble glides back to its prompt, which the pin grows into", (tester) async {
      await _pumpTurns(tester, messages: shortTurns);
      await _scrollRowTo(tester, rowId: "a8-0", top: _topInset - 100);
      final moves = _recordMoves(tester);

      await tester.tapAt(pinnedBubble(tester, "u8").center);
      await tester.pumpAndSettle(const Duration(milliseconds: 16));

      expect(moves.length, greaterThan(5), reason: "a glide, not a jump");
      for (final (index, pixels) in moves.indexed.skip(1)) {
        expect(pixels, greaterThanOrEqualTo(moves[index - 1]), reason: "the glide never turns back");
      }
      expect(ownBubble(tester, "u8").top, moreOrLessEquals(pinTop, epsilon: 0.5));
      final pin = pinOf(tester, "u8") ?? fail("u8 is not pinned");
      expect(pin.height, pin.fullHeight, reason: "the pin has grown back into its bubble");
      expect(find.byKey(_jumpToLatestKey), findsOneWidget);
    });

    testWidgets("a tap under reduced motion jumps back to its prompt", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pumpTurns(tester, messages: shortTurns);
      await _scrollRowTo(tester, rowId: "a8-0", top: _topInset - 100);
      final moves = _recordMoves(tester);

      await tester.tapAt(pinnedBubble(tester, "u8").center);
      await tester.pumpAndSettle();

      expect(moves.length, lessThanOrEqualTo(2), reason: "a jump, not a glide");
      expect(ownBubble(tester, "u8").top, moreOrLessEquals(pinTop, epsilon: 0.5));
    });

    testWidgets("a tap on the band beside the bubble does nothing", (tester) async {
      await _pumpTurns(tester, messages: shortTurns);
      await _scrollRowTo(tester, rowId: "a8-0", top: _topInset - 100);
      final offset = _position(tester).pixels;
      final bubble = pinnedBubble(tester, "u8");

      await tester.tapAt(Offset(bubble.left / 2, bubble.center.dy));
      await tester.pumpAndSettle();

      expect(_position(tester).pixels, offset);
      expect(pinOf(tester, "u8"), isNotNull);
    });

    testWidgets("a drag that starts on the pin still scrolls the rows beneath", (tester) async {
      await _pumpTurns(tester, messages: shortTurns);
      await _scrollRowTo(tester, rowId: "a8-0", top: _topInset - 100);
      final offset = _position(tester).pixels;

      await tester.dragFrom(pinnedBubble(tester, "u8").center, const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(_position(tester).pixels, isNot(moreOrLessEquals(offset, epsilon: 1)));
    });

    testWidgets("while pinned is a labelled button that glides to its unbuilt prompt", (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpTurns(tester, messages: tallTurns);
      await _scrollRowTo(tester, rowId: "a6-1", top: _topInset - 100);
      expect(find.byKey(const ValueKey("u6"), skipOffstage: false), findsNothing);

      final node = tester.getSemantics(copyOf("u6"));
      expect(
        node,
        isSemantics(
          label: _multilineText(label: "Prompt 6", lines: 40),
          hint: "Jump to this prompt",
          isButton: true,
          hasTapAction: true,
        ),
      );
      node.owner?.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();

      expect(ownBubble(tester, "u6").top, moreOrLessEquals(pinTop, epsilon: 0.5));
      semantics.dispose();
    });
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
  }, variant: _pinchPlatforms);

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
  }, variant: _pinchPlatforms);

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
  }, variant: _pinchPlatforms);

  group("the Prompts screen's seams", () {
    final shortTurns = _turns(count: 20, promptLines: 1, answers: 1, paragraphs: 12);
    // Turn 3 gains a follow-up, sent before the agent answered.
    final withFollowUp = [
      for (final message in shortTurns) ...[
        message,
        if (message.info.id == "u3") _message(messageId: "u3f", role: "user", text: "Also this", promptId: "p3f"),
      ],
    ];
    // Where a jump rests a prompt's row: its bubble on the pin line.
    const promptRowTop = _topInset + 2;

    testWidgets("names the prompt the pin names, else the next one below", (tester) async {
      final lead = _message(
        messageId: "lead",
        role: "assistant",
        text: _multilineText(label: "Lead", lines: 60),
      );
      final harness = await _pumpTurns(tester, messages: [lead, ...shortTurns]);

      await _scrollRowTo(tester, rowId: "a8-0", top: _topInset - 100);
      expect(harness.currentPromptId.value, "u8");

      await _scrollRowTo(tester, rowId: "lead", top: _topInset);
      expect(harness.currentPromptId.value, "u0", reason: "no prompt opens the oldest turn");
    });

    testWidgets("a jump lands an unbuilt prompt on the pin line and stops following", (tester) async {
      final harness = await _pumpTurns(tester, messages: withFollowUp);
      expect(_messageKey("u3").evaluate(), isEmpty);

      var landed = false;
      unawaited(harness.jumpNotifier.jumpTo(messageId: "u3").then((_) => landed = true));
      await tester.pump();
      await tester.pump();
      expect(landed, isFalse, reason: "a far row takes more than one step");
      await tester.pumpAndSettle();

      expect(_topOf(tester, "u3"), moreOrLessEquals(promptRowTop, epsilon: 0.5));
      expect(find.byKey(_jumpToLatestKey), findsOneWidget);
      expect(landed, isTrue);
    });

    testWidgets("a jump lands a follow-up, by its own row, just below its pinned prompt, every time", (tester) async {
      final harness = await _pumpTurns(tester, messages: withFollowUp);
      final pins = tester.renderObject<RenderTranscriptStickyPrompts>(find.byType(TranscriptStickyPromptOverlay));
      final followUpTop = promptRowTop + pins.compactHeight + transcriptStickyGap;

      unawaited(harness.jumpNotifier.jumpTo(messageId: "u3f"));
      await tester.pumpAndSettle();
      expect(_topOf(tester, "session-detail-prompt-p3f"), moreOrLessEquals(followUpTop, epsilon: 0.5));

      _position(tester).jumpTo(_position(tester).pixels - 400);
      await tester.pumpAndSettle();
      unawaited(harness.jumpNotifier.jumpTo(messageId: "u3f"));
      await tester.pumpAndSettle();
      expect(_topOf(tester, "session-detail-prompt-p3f"), moreOrLessEquals(followUpTop, epsilon: 0.5));
    });

    testWidgets("a jump reaches a prompt that arrived after the reader scrolled away", (tester) async {
      final harness = await _pumpTurns(tester, messages: withFollowUp);
      _position(tester).jumpTo(_position(tester).pixels + 2000);
      await tester.pumpAndSettle();
      expect(find.byKey(_jumpToLatestKey), findsOneWidget);
      harness.appendNewestMessage(_message(messageId: "late", role: "user", text: "Late prompt"));
      harness.appendNewestMessage(
        _message(
          messageId: "late-answer",
          role: "assistant",
          text: [for (var line = 0; line < 40; line++) "Late paragraph $line"].join("\n\n"),
        ),
      );
      await tester.pumpAndSettle();
      expect(_messageKey("late").evaluate(), isEmpty);

      unawaited(harness.jumpNotifier.jumpTo(messageId: "late"));
      await tester.pumpAndSettle();

      expect(_topOf(tester, "late"), lessThan(_topInset + 100));
    });

    testWidgets("a jump to a message that is gone moves nothing", (tester) async {
      final harness = await _pumpTurns(tester, messages: withFollowUp);
      final offset = _position(tester).pixels;

      var landed = false;
      unawaited(harness.jumpNotifier.jumpTo(messageId: "gone").then((_) => landed = true));
      await tester.pump();
      expect(landed, isTrue, reason: "a jump that cannot move ends at once");
      await tester.pumpAndSettle();

      expect(_position(tester).pixels, offset);
      expect(find.byKey(_jumpToLatestKey), findsNothing);
    });
  });
}

QueuedSessionSubmission _textSubmission({required String promptId, required String text}) =>
    QueuedSessionSubmission.text(
      promptId: promptId,
      text: text,
      inputMode: ComposerInputMode.typed,
      attachments: const [],
      agent: null,
      agentModel: null,
      fastMode: false,
    );
