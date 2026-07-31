import "dart:typed_data";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_detail/widgets/file_part_widget.dart";
import "package:sesori_mobile/features/session_detail/widgets/image_attachment_viewer.dart";
import "package:sesori_mobile/features/session_detail/widgets/tool_part_widget.dart";
import "package:sesori_mobile/features/session_detail/widgets/user_message_card.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockUrlLauncher extends Mock implements UrlLauncher {}

class _FakePhotoLibrary implements PhotoLibrary {
  Uint8List? savedBytes;
  String? savedFilename;

  @override
  Future<PhotoLibrarySaveResult> saveImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    savedBytes = bytes;
    savedFilename = filename;
    return PhotoLibrarySaveResult.saved;
  }
}

class _FakeImageClipboard implements ImageClipboard {
  Uint8List? copiedBytes;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {
    copiedBytes = bytes;
  }
}

class _FakeImageSharer implements ImageSharer {
  @override
  Future<void> shareImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
    required ImageShareOrigin? origin,
  }) async {}
}

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
  late _FakePhotoLibrary photoLibrary;
  late _FakeImageClipboard imageClipboard;
  late _FakeImageSharer imageSharer;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(UrlLaunchMode.externalApp);
  });

  setUp(() async {
    await GetIt.instance.reset();
    urlLauncher = _MockUrlLauncher();
    photoLibrary = _FakePhotoLibrary();
    imageClipboard = _FakeImageClipboard();
    imageSharer = _FakeImageSharer();
    when(() => urlLauncher.launch(any(), mode: any(named: "mode"))).thenAnswer((_) async => true);
    GetIt.instance.registerSingleton<UrlLauncher>(urlLauncher);
    GetIt.instance.registerSingleton<PhotoLibrary>(photoLibrary);
    GetIt.instance.registerSingleton<ImageClipboard>(imageClipboard);
    GetIt.instance.registerSingleton<ImageSharer>(imageSharer);
    GetIt.instance.registerSingleton<MessageImageRepository>(
      MessageImageRepository(
        api: MessageImageApi(
          client: MockClient((_) async => throw StateError("Unexpected remote image request")),
        ),
      ),
    );
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

  testWidgets("opens inline images in a zoomable Hero viewer using the same provider", (tester) async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
      filename: "image.png",
    );

    await tester.pumpWidget(_app(child: const FilePartWidget(attachment: attachment)));
    await _finishAsyncDecode(tester: tester);

    final preview = tester.widget<Image>(find.byKey(FilePartWidget.previewImageKey));
    await tester.tap(find.byKey(FilePartWidget.previewTapTargetKey));
    await tester.pumpAndSettle();

    expect(find.byType(ImageAttachmentViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byIcon(Icons.content_copy), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    final fullscreen = tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey));
    expect(identical(fullscreen.image, preview.image), isTrue);
    final memoryImage = (preview.image as ResizeImage).imageProvider as MemoryImage;

    await tester.tap(find.byIcon(Icons.content_copy));
    await tester.pump();

    expect(identical(imageClipboard.copiedBytes, memoryImage.bytes), isTrue);
    expect(find.text("Image copied to clipboard"), findsOneWidget);
  });

  testWidgets("keeps display and action filenames separate when saving", (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bytes = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]);
    final image = LoadedMessageImage(
      bytes: bytes,
      provider: MemoryImage(bytes),
      mime: "image/png",
      actionFilename: "unsafe.png",
      originalUri: Uri.parse("https://files.example.com/unsafe.png"),
    );

    await tester.pumpWidget(
      _app(
        child: BlocProvider(
          create: (_) => ImageAttachmentActionsCubit(
            photoLibrary: photoLibrary,
            imageClipboard: imageClipboard,
            imageSharer: imageSharer,
            bytes: bytes,
            mime: "image/png",
            actionFilename: "unsafe.png",
          ),
          child: ImageAttachmentViewer(
            image: image,
            filename: "../../unsafe.exe",
            heroTag: Object(),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byIcon(Icons.content_copy), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pump();

    expect(photoLibrary.savedFilename, "unsafe.png");
    expect(identical(photoLibrary.savedBytes, bytes), isTrue);
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

  testWidgets("auto-loads an HTTPS raster attachment once without launching it", (tester) async {
    var requests = 0;
    await GetIt.instance.unregister<MessageImageRepository>();
    GetIt.instance.registerSingleton<MessageImageRepository>(
      MessageImageRepository(
        api: MessageImageApi(
          client: MockClient((_) async {
            requests++;
            return http.Response.bytes(
              Uint8List.fromList(
                const [
                  0x89,
                  0x50,
                  0x4E,
                  0x47,
                  0x0D,
                  0x0A,
                  0x1A,
                  0x0A,
                ],
              ),
              200,
            );
          }),
        ),
      ),
    );
    const attachment = MessageAttachment.remoteUrl(
      mime: "image/png",
      url: "https://files.example.com/image.png",
      filename: "image.png",
    );

    await tester.pumpWidget(_app(child: const FilePartWidget(attachment: attachment)));
    await _finishAsyncDecode(tester: tester);
    await tester.pump();

    expect(find.byKey(FilePartWidget.previewImageKey), findsOneWidget);
    expect(requests, 1);
    verifyNever(() => urlLauncher.launch(any(), mode: any(named: "mode")));
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

  testWidgets("does not render a hardcoded MIME fallback", (tester) async {
    const attachment = MessageAttachment.metadata(
      mime: " ",
      filename: "unknown.bin",
    );

    await tester.pumpWidget(_app(child: const FilePartWidget(attachment: attachment)));

    expect(find.text("unknown.bin"), findsOneWidget);
    expect(find.text("application/octet-stream"), findsNothing);
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
