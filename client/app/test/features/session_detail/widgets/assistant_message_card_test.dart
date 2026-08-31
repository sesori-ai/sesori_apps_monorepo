import "dart:typed_data";
import "dart:ui" show SemanticsAction;

import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_detail/widgets/assistant_message_card.dart";
import "package:sesori_mobile/features/session_detail/widgets/attachment_collection_widget.dart";
import "package:sesori_mobile/features/session_detail/widgets/file_part_widget.dart";
import "package:sesori_mobile/features/session_detail/widgets/image_attachment_viewer.dart";
import "package:sesori_mobile/features/session_detail/widgets/text_part_widget.dart";
import "package:sesori_mobile/features/session_detail/widgets/tool_part_widget.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionApi() extends Mock implements SessionApi;

class _MockAuthSession() extends Mock implements AuthSession;

class _MockAttachmentThumbnailStorage() extends Mock implements AttachmentThumbnailStorage;

class const _AssistantMessageCardHarness({
  super.key,
  required final MessageWithParts message,
  required final Map<String, String> streamingText,
}) extends StatefulWidget {
  @override
  State<_AssistantMessageCardHarness> createState() => _AssistantMessageCardHarnessState();
}

class _AssistantMessageCardHarnessState() extends State<_AssistantMessageCardHarness> {
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
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AssistantMessageCard(
          projectId: null,
          message: widget.message,
          streamingText: _streamingText,
          children: const <Session>[],
          childStatuses: const <String, SessionStatus>{},
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      time: null,
    ),
    parts: parts,
  );
}

MessagePart _textPart({required String id, required String text}) {
  return MessagePart.text(
    id: id,
    sessionID: "session-1",
    messageID: "assistant-1",
    text: text,
  );
}

MessagePartTool _toolPart({required String id, required String toolName}) {
  final part = MessagePart.tool(
    id: id,
    sessionID: "session-1",
    messageID: "assistant-1",
    tool: toolName,
  );
  if (part case final MessagePartTool toolPart) return toolPart;
  throw StateError("MessagePart.tool returned a non-tool variant");
}

MessagePartTool _runningCompactionPart() {
  const part = MessagePart.tool(
    id: "compaction-tool",
    sessionID: "session-1",
    messageID: "assistant-1",
    tool: "compact",
    state: ToolState(
      status: ToolStatus.running,
      shellCommand: null,
      output: null,
      error: null,
      attachments: [],
    ),
  );
  if (part case final MessagePartTool toolPart) return toolPart;
  throw StateError("MessagePart.tool returned a non-tool variant");
}

MessagePart _filePart({required String id, String filename = "report.pdf"}) {
  return MessagePart.file(
    id: id,
    sessionID: "session-1",
    messageID: "assistant-1",
    attachment: MessageAttachment.metadata(mime: "application/pdf", filename: filename),
  );
}

MessagePart _hiddenPart({required String id}) {
  return MessagePart.snapshot(
    id: id,
    sessionID: "session-1",
    messageID: "assistant-1",
  );
}

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    final authSession = _MockAuthSession();
    when(() => authSession.currentState).thenReturn(const AuthState.unauthenticated());
    GetIt.instance.registerSingleton<MessageImageRepository>(
      MessageImageRepository(
        api: MessageImageApi(client: MockClient((_) async => http.Response("unexpected", 500))),
        sessionApi: _MockSessionApi(),
        authSession: authSession,
        attachmentThumbnailStorage: _MockAttachmentThumbnailStorage(),
      ),
    );
  });

  tearDown(() => GetIt.instance.reset());

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
    expect(find.byType(PregoReadableSelectionArea), findsOneWidget);
    expect(find.byType(MarkdownBody), findsNWidgets(2));

    final markdownBodies = tester.widgetList<MarkdownBody>(find.byType(MarkdownBody)).toList();
    expect(markdownBodies.map((widget) => widget.data), ['First paragraph', 'Second paragraph']);

    // Verify selectable is disabled so SelectionArea owns selection.
    for (final body in markdownBodies) {
      expect(body.selectable, isFalse);
    }
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

  testWidgets("renders compatibility defaults with meaningful labels", (tester) async {
    await tester.pumpWidget(
      _AssistantMessageCardHarness(
        message: _assistantMessage(
          parts: const [
            MessagePart.tool(id: "tool", sessionID: "session-1", messageID: "assistant-1"),
            MessagePart.subtask(id: "subtask", sessionID: "session-1", messageID: "assistant-1"),
            MessagePart.agent(id: "agent", sessionID: "session-1", messageID: "assistant-1"),
            MessagePart.retry(id: "retry", sessionID: "session-1", messageID: "assistant-1"),
          ],
        ),
        streamingText: const {},
      ),
    );

    expect(find.text("Tool"), findsOneWidget);
    expect(find.text("Pending"), findsOneWidget);
    expect(find.text("Background task"), findsOneWidget);
    expect(find.text("Agent"), findsOneWidget);
    expect(find.text("Retry"), findsOneWidget);
  });

  testWidgets("renders an active compaction tool as running", (tester) async {
    await tester.pumpWidget(
      _AssistantMessageCardHarness(
        message: _assistantMessage(parts: [_runningCompactionPart()]),
        streamingText: const {},
      ),
    );

    expect(find.text("compact"), findsOneWidget);
    expect(find.text("Running"), findsOneWidget);
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

  testWidgets("opens a decoded Markdown image in the full-screen viewer", (tester) async {
    final semantics = tester.ensureSemantics();
    const imageData =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==";

    await tester.pumpWidget(
      _AssistantMessageCardHarness(
        message: _assistantMessage(
          parts: [_textPart(id: "image-part", text: "![Test image]($imageData)")],
        ),
        streamingText: const {},
      ),
    );
    await tester.pumpAndSettle();

    final markdownImage = find.byType(MarkdownMessageImage);
    expect(markdownImage, findsOneWidget);
    final preview = tester.widget<Image>(find.descendant(of: markdownImage, matching: find.byType(Image)));
    expect(preview.image, isA<ResizeImage>());
    expect((preview.image as ResizeImage).imageProvider, isA<MemoryImage>());
    await tester.runAsync(
      () => precacheImage(
        preview.image,
        tester.element(markdownImage),
      ),
    );
    await tester.pumpAndSettle();
    final tapTarget = tester.widget<GestureDetector>(
      find.descendant(of: markdownImage, matching: find.byType(GestureDetector)),
    );
    expect(tapTarget.onTap, isNotNull);
    expect(
      tester.getSemantics(markdownImage).getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    tapTarget.onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));

    expect(find.byKey(ImageAttachmentViewer.flightCropImageKey), findsNothing);
    expect(find.byKey(ImageAttachmentViewer.flightFullImageKey), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(ImageAttachmentViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byIcon(Icons.content_copy), findsNothing);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
    final fullscreen = tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey));
    expect(identical(fullscreen.image, preview.image), isTrue);
    semantics.dispose();
  });

  testWidgets("bounds remote Markdown image decode dimensions", (tester) async {
    const uri = "https://example.com/image.png";
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MarkdownMessageImage(
            uri: Uri.parse(uri),
            semanticLabel: "Remote image",
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    final provider = image.image as ResizeImage;
    expect(provider.width, 2048);
    expect(provider.height, 2048);
    expect(provider.policy, ResizeImagePolicy.fit);
    expect(provider.imageProvider, isA<NetworkImage>());
    expect((provider.imageProvider as NetworkImage).url, uri);
  });

  testWidgets("rejects oversized Markdown data images before decoding", (tester) async {
    final oversizedUri = Uri.dataFromBytes(
      Uint8List(maxInlineMessageAttachmentBytes + 1),
      mimeType: "image/png",
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MarkdownMessageImage(
            uri: oversizedUri,
            semanticLabel: "Oversized image",
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets("renders normalized assistant file attachments", (tester) async {
    await tester.pumpWidget(
      _AssistantMessageCardHarness(
        message: _assistantMessage(parts: [_filePart(id: "file-1")]),
        streamingText: const {},
      ),
    );

    expect(find.byType(FilePartWidget), findsOneWidget);
    expect(find.text("report.pdf"), findsOneWidget);
  });

  testWidgets("groups only contiguous assistant file runs without changing chronology", (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _AssistantMessageCardHarness(
        message: _assistantMessage(
          parts: [
            _textPart(id: "before", text: "Before files"),
            _filePart(id: "file-1", filename: "one.pdf"),
            _filePart(id: "file-2", filename: "two.pdf"),
            _toolPart(id: "tool", toolName: "Search files"),
            _filePart(id: "file-3", filename: "three.pdf"),
            _textPart(id: "after", text: "After files"),
          ],
        ),
        streamingText: const {},
      ),
    );

    expect(find.byType(AttachmentCollectionWidget), findsNWidgets(2));
    final beforeY = tester.getTopLeft(find.text("Before files")).dy;
    final firstCollectionY = tester.getTopLeft(find.byType(AttachmentCollectionWidget).first).dy;
    final toolY = tester.getTopLeft(find.byType(ToolPartWidget)).dy;
    final secondCollectionY = tester.getTopLeft(find.byType(AttachmentCollectionWidget).last).dy;
    final afterY = tester.getTopLeft(find.text("After files")).dy;
    expect(beforeY, lessThan(firstCollectionY));
    expect(firstCollectionY, lessThan(toolY));
    expect(toolY, lessThan(secondCollectionY));
    expect(secondCollectionY, lessThan(afterY));
  });

  testWidgets("hidden assistant parts remain attachment run boundaries", (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _AssistantMessageCardHarness(
        message: _assistantMessage(
          parts: [
            _filePart(id: "file-1", filename: "one.pdf"),
            _hiddenPart(id: "snapshot"),
            _filePart(id: "file-2", filename: "two.pdf"),
          ],
        ),
        streamingText: const {},
      ),
    );

    expect(find.byType(AttachmentCollectionWidget), findsNWidgets(2));
  });
}
