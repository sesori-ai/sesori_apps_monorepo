import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/features/session_detail/widgets/session_detail_message_list.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";

class _SessionDetailMessageListHarness extends StatefulWidget {
  final List<MessageWithParts> initialMessages;
  final Map<String, String> initialStreamingText;

  const _SessionDetailMessageListHarness({
    super.key,
    required this.initialMessages,
    required this.initialStreamingText,
  });

  @override
  State<_SessionDetailMessageListHarness> createState() => _SessionDetailMessageListHarnessState();
}

class _SessionDetailMessageListHarnessState extends State<_SessionDetailMessageListHarness> {
  late List<MessageWithParts> _messages;
  late Map<String, String> _streamingText;

  @override
  void initState() {
    super.initState();
    _messages = widget.initialMessages;
    _streamingText = widget.initialStreamingText;
  }

  void appendNewestMessage(MessageWithParts message) {
    setState(() => _messages = [..._messages, message]);
  }

  void updateStreamingText({required String partId, required String text}) {
    setState(() => _streamingText = {..._streamingText, partId: text});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SessionDetailMessageList(
          projectId: null,
          messages: _messages,
          streamingText: _streamingText,
          children: const <Session>[],
          childStatuses: const <String, SessionStatus>{},
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
}) {
  final resolvedPartId = partId ?? "$messageId-part";

  return MessageWithParts(
    info: Message(
      id: messageId,
      role: role,
      sessionID: "session-1",
      agent: null,
      modelID: null,
      providerID: null,
    ),
    parts: [
      MessagePart(
        id: resolvedPartId,
        sessionID: "session-1",
        messageID: messageId,
        type: MessagePartType.text,
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

Future<void> _detachViewportWithoutDrag(WidgetTester tester) async {
  _position(tester).jumpTo(500);
  await tester.pump();
  await tester.pump();

  expect(_position(tester).pixels, greaterThan(20));
  expect(find.byKey(_jumpToLatestKey), findsOneWidget);
}

void main() {
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

  testWidgets("non-drag scroll updates also detach follow mode", (tester) async {
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

    await _detachViewportWithoutDrag(tester);
    final anchor = _messageKey("user-7");
    final before = tester.getTopLeft(anchor).dy;

    harnessKey.currentState!.appendNewestMessage(
      _message(
        messageId: "user-wheel",
        role: "user",
        text: _multilineText(label: "Wheel newest", lines: 10),
      ),
    );
    await _pumpListUpdate(tester);

    final after = tester.getTopLeft(anchor).dy;
    expect(after, closeTo(before, 0.1));
    expect(find.byKey(_jumpToLatestKey), findsOneWidget);
  });
}
