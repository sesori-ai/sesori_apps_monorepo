import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_detail/widgets/file_part_widget.dart";
import "package:sesori_mobile/features/session_detail/widgets/tool_part_widget.dart";
import "package:sesori_mobile/features/session_detail/widgets/user_message_card.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockUrlLauncher extends Mock implements UrlLauncher {}

Widget _app({required Widget child}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Future<void> _finishAsyncDecode({required WidgetTester tester}) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  late _MockUrlLauncher urlLauncher;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(UrlLaunchMode.externalApp);
  });

  setUp(() async {
    await GetIt.instance.reset();
    urlLauncher = _MockUrlLauncher();
    when(() => urlLauncher.launch(any(), mode: any(named: "mode"))).thenAnswer((_) async => true);
    GetIt.instance.registerSingleton<UrlLauncher>(urlLauncher);
  });

  tearDown(() => GetIt.instance.reset());

  testWidgets("renders a bounded inline image without a network request", (tester) async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
      filename: "image.png",
    );

    await tester.pumpWidget(_app(child: const FilePartWidget(attachment: attachment)));
    await _finishAsyncDecode(tester: tester);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).imageProvider, isA<MemoryImage>());
    verifyNever(() => urlLauncher.launch(any(), mode: any(named: "mode")));
  });

  testWidgets("opens a safe remote attachment only after a tap", (tester) async {
    const attachment = MessageAttachment.remoteUrl(
      mime: "application/pdf",
      url: "https://files.example.com/report.pdf",
      filename: "report.pdf",
    );

    await tester.pumpWidget(_app(child: const FilePartWidget(attachment: attachment)));

    expect(find.byType(Image), findsNothing);
    verifyNever(() => urlLauncher.launch(any(), mode: any(named: "mode")));

    await tester.tap(find.text("report.pdf"));
    await tester.pump();

    verify(
      () => urlLauncher.launch(Uri.parse("https://files.example.com/report.pdf"), mode: UrlLaunchMode.externalApp),
    ).called(1);
  });

  testWidgets("does not launch unsafe remote schemes", (tester) async {
    const attachment = MessageAttachment.remoteUrl(
      mime: "application/pdf",
      url: "intent://open/report.pdf",
      filename: "report.pdf",
    );

    await tester.pumpWidget(_app(child: const FilePartWidget(attachment: attachment)));
    await tester.tap(find.text("report.pdf"), warnIfMissed: false);

    verifyNever(() => urlLauncher.launch(any(), mode: any(named: "mode")));
  });

  testWidgets("degrades malformed inline data to a metadata tile", (tester) async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "%%%",
      filename: "broken.png",
    );

    await tester.pumpWidget(_app(child: const FilePartWidget(attachment: attachment)));
    await _finishAsyncDecode(tester: tester);

    expect(find.text("broken.png"), findsOneWidget);
    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("renders completed tool attachments", (tester) async {
    const part = MessagePart(
      id: "part-1",
      sessionID: "session-1",
      messageID: "message-1",
      type: MessagePartType.tool,
      text: null,
      tool: "browser",
      state: ToolState(
        status: ToolStatus.completed,
        title: "Screenshot",
        output: null,
        error: null,
        attachments: [
          MessageAttachment.metadata(mime: "image/png", filename: "screenshot.png"),
        ],
      ),
      prompt: null,
      description: null,
      agent: null,
      agentName: null,
      attempt: null,
      retryError: null,
      attachment: null,
    );

    await tester.pumpWidget(_app(child: const ToolPartWidget(part: part)));

    expect(find.text("screenshot.png"), findsOneWidget);
  });

  testWidgets("renders normalized user file attachments", (tester) async {
    const message = MessageWithParts(
      info: Message.user(
        id: "message-1",
        sessionID: "session-1",
        agent: null,
        time: null,
      ),
      parts: [
        MessagePart(
          id: "part-1",
          sessionID: "session-1",
          messageID: "message-1",
          type: MessagePartType.file,
          text: null,
          tool: null,
          state: null,
          prompt: null,
          description: null,
          agent: null,
          agentName: null,
          attempt: null,
          retryError: null,
          attachment: MessageAttachment.metadata(mime: "text/plain", filename: "notes.txt"),
        ),
      ],
    );

    await tester.pumpWidget(_app(child: const UserMessageCard(message: message)));

    expect(find.text("notes.txt"), findsOneWidget);
  });
}
