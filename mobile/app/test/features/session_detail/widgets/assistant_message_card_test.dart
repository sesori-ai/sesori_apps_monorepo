import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/features/session_detail/widgets/assistant_message_card.dart";
import "package:sesori_mobile/features/session_detail/widgets/tool_part_widget.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";

class _AssistantMessageCardHarness extends StatefulWidget {
  final MessageWithParts message;
  final Map<String, String> streamingText;

  const _AssistantMessageCardHarness({
    super.key,
    required this.message,
    required this.streamingText,
  });

  @override
  State<_AssistantMessageCardHarness> createState() => _AssistantMessageCardHarnessState();
}

class _AssistantMessageCardHarnessState extends State<_AssistantMessageCardHarness> {
  late Map<String, String> _streamingText;

  @override
  void initState() {
    super.initState();
    _streamingText = widget.streamingText;
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
        body: AssistantMessageCard(
          projectId: null,
          message: widget.message,
          streamingText: _streamingText,
          children: const <Session>[],
          childStatuses: const <String, SessionStatus>{},
        ),
      ),
    );
  }
}

MessageWithParts _assistantMessage({required List<MessagePart> parts}) {
  return MessageWithParts(
    info: const Message.assistant(
      id: "assistant-1",
      sessionID: "session-1",
      agent: null,
      modelID: null,
      providerID: null,
    ),
    parts: parts,
  );
}

MessagePart _textPart({required String id, required String text}) {
  return MessagePart(
    id: id,
    sessionID: "session-1",
    messageID: "assistant-1",
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
  );
}

MessagePart _toolPart({required String id, required String toolName}) {
  return MessagePart(
    id: id,
    sessionID: "session-1",
    messageID: "assistant-1",
    type: MessagePartType.tool,
    text: null,
    tool: toolName,
    state: null,
    prompt: null,
    description: null,
    agent: null,
    agentName: null,
    attempt: null,
    retryError: null,
  );
}

void main() {
  testWidgets("renders one SelectionArea and two markdown parts for assistant text", (tester) async {
    await tester.pumpWidget(
      _AssistantMessageCardHarness(
        message: _assistantMessage(
          parts: [
            _textPart(id: "part-1", text: "First paragraph"),
            _textPart(id: "part-2", text: "Second paragraph"),
          ],
        ),
        streamingText: const {},
      ),
    );

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.byType(MarkdownBody), findsNWidgets(2));

    final markdownBodies = tester.widgetList<MarkdownBody>(find.byType(MarkdownBody)).toList();
    expect(markdownBodies.map((widget) => widget.data), ['First paragraph', 'Second paragraph']);
  });

  testWidgets("preserves mixed text-tool-text rendering inside one SelectionArea", (tester) async {
    await tester.pumpWidget(
      _AssistantMessageCardHarness(
        message: _assistantMessage(
          parts: [
            _textPart(id: "part-1", text: "Before tool"),
            _toolPart(id: "part-2", toolName: "Search files"),
            _textPart(id: "part-3", text: "After tool"),
          ],
        ),
        streamingText: const {},
      ),
    );

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.byType(MarkdownBody), findsNWidgets(2));
    expect(find.byType(ToolPartWidget), findsOneWidget);

    final markdownBodies = tester.widgetList<MarkdownBody>(find.byType(MarkdownBody)).toList();
    expect(markdownBodies.map((widget) => widget.data), ['Before tool', 'After tool']);
  });

  testWidgets("streaming text updates the rendered markdown without breaking the SelectionArea", (tester) async {
    final harnessKey = GlobalKey<_AssistantMessageCardHarnessState>();
    const partId = "streaming-part";

    await tester.pumpWidget(
      _AssistantMessageCardHarness(
        key: harnessKey,
        message: _assistantMessage(
          parts: [_textPart(id: partId, text: "final text")],
        ),
        streamingText: const {partId: "draft text"},
      ),
    );

    expect(find.byType(SelectionArea), findsOneWidget);
    expect(tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data, "draft text");

    harnessKey.currentState!.updateStreamingText(partId: partId, text: "updated draft text");
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(tester.widget<MarkdownBody>(find.byType(MarkdownBody)).data, "updated draft text");
  });
}
