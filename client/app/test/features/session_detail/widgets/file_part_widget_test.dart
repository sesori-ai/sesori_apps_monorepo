import "dart:async";
import "dart:convert";
import "dart:typed_data";
import "dart:ui" show SemanticsAction;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/session_detail/widgets/attachment_collection_widget.dart";
import "package:sesori_mobile/features/session_detail/widgets/file_part_widget.dart";
import "package:sesori_mobile/features/session_detail/widgets/image_attachment_viewer.dart";
import "package:sesori_mobile/features/session_detail/widgets/tool_part_widget.dart";
import "package:sesori_mobile/features/session_detail/widgets/user_message_card.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockUrlLauncher() extends Mock implements UrlLauncher;

class _MockSessionApi() extends Mock implements SessionApi;

class _MockAuthSession() extends Mock implements AuthSession;

class _MockAttachmentThumbnailStorage() extends Mock implements AttachmentThumbnailStorage;

class _MockMessageImageRepository() extends Mock implements MessageImageRepository;

const _authUser = AuthUser(
  id: "account-a",
  provider: AuthProvider.github,
  providerUserId: "provider-a",
  providerUsername: "alice",
);
const _pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==";
const _widePngBase64 =
    "iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAEklEQVR4nGP4z8DwHxkzoAsAAA8hD/EEN8afAAAAAElFTkSuQmCC";

class _FakeImageSaver() implements ImageSaver {
  Uint8List? savedBytes;
  String? savedFilename;

  @override
  Future<ImageSaveResult> saveImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
  }) async {
    savedBytes = bytes;
    savedFilename = filename;
    return ImageSaveResult.saved;
  }
}

class _FakeImageClipboard() implements ImageClipboard {
  Uint8List? copiedBytes;

  @override
  Future<Uint8List?> readImage() async => null;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {
    copiedBytes = bytes;
  }
}

class _FakeImageSharer() implements ImageSharer {
  @override
  Future<void> shareImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
    required ImageShareOrigin? origin,
  }) async {}
}

Widget _app({required Widget child, ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
    themeMode: themeMode,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Future<void> _finishAsyncDecode({required WidgetTester tester}) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

Future<void> _openImageViewer({required WidgetTester tester}) async {
  await _finishAsyncDecode(tester: tester);
  final preview = tester.widget<Image>(find.byKey(FilePartWidget.previewImageKey));
  await tester.runAsync(
    () => precacheImage(
      preview.image,
      tester.element(find.byKey(FilePartWidget.previewImageKey)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(FilePartWidget.previewTapTargetKey));
  await tester.pumpAndSettle();
}

Future<void> _doubleTap({required WidgetTester tester, required Finder finder}) async {
  final position = tester.getCenter(finder);
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

void main() {
  late _MockUrlLauncher urlLauncher;
  late _FakeImageSaver imageSaver;
  late _FakeImageClipboard imageClipboard;
  late _FakeImageSharer imageSharer;
  late _MockSessionApi sessionApi;
  late _MockAuthSession authSession;
  late _MockAttachmentThumbnailStorage thumbnailStorage;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(UrlLaunchMode.externalApp);
    registerFallbackValue(const MessageAttachment.unknown());
    registerFallbackValue(SessionAttachmentRendition.thumbnail);
  });

  setUp(() async {
    await GetIt.instance.reset();
    urlLauncher = _MockUrlLauncher();
    imageSaver = _FakeImageSaver();
    imageClipboard = _FakeImageClipboard();
    imageSharer = _FakeImageSharer();
    sessionApi = _MockSessionApi();
    authSession = _MockAuthSession();
    thumbnailStorage = _MockAttachmentThumbnailStorage();
    when(() => authSession.currentState).thenReturn(const AuthState.unauthenticated());
    when(() => urlLauncher.launch(any(), mode: any(named: "mode"))).thenAnswer((_) async => true);
    GetIt.instance.registerSingleton<UrlLauncher>(urlLauncher);
    GetIt.instance.registerSingleton<ImageSaver>(imageSaver);
    GetIt.instance.registerSingleton<ImageClipboard>(imageClipboard);
    GetIt.instance.registerSingleton<ImageSharer>(imageSharer);
    GetIt.instance.registerSingleton<MessageImageRepository>(
      MessageImageRepository(
        api: MessageImageApi(
          client: MockClient((_) async => throw StateError("Unexpected remote image request")),
        ),
        sessionApi: sessionApi,
        authSession: authSession,
        attachmentThumbnailStorage: thumbnailStorage,
      ),
    );
  });

  tearDown(() => GetIt.instance.reset());

  testWidgets("renders stored images as metadata until reference delivery is enabled", (tester) async {
    const attachment = MessageAttachment.storedImage(
      attachmentId: "attachment-1",
      bridgeId: "bridge-1",
      mime: "image/png",
      filename: "preview.png",
      byteLength: 1024,
    );

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("preview.png"), findsOneWidget);
    expect(find.text("image/png / 1024 bytes"), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(FilePartWidget.previewTapTargetKey), findsNothing);
  });

  testWidgets("renders a bounded inline image without a network request", (tester) async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
      filename: "image.png",
    );

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _finishAsyncDecode(tester: tester);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).imageProvider, isA<MemoryImage>());
    verifyNever(() => urlLauncher.launch(any(), mode: any(named: "mode")));
  });

  testWidgets("lays out one two three and four attachments as capped square grids", (tester) async {
    const attachments = [
      MessageAttachment.metadata(mime: "image/png", filename: "one.png"),
      MessageAttachment.metadata(mime: "image/png", filename: "two.png"),
      MessageAttachment.metadata(mime: "image/png", filename: "three.png"),
      MessageAttachment.metadata(mime: "image/png", filename: "four.png"),
    ];

    for (var count = 1; count <= attachments.length; count++) {
      await tester.pumpWidget(
        _app(
          child: SizedBox(
            width: 500,
            child: AttachmentCollectionWidget(
              sessionId: "session-1",
              attachments: attachments.take(count).toList(),
            ),
          ),
        ),
      );

      final collection = find.byType(AttachmentCollectionWidget);
      expect(tester.getSize(find.byKey(AttachmentCollectionWidget.surfaceKey)).width, 320);
      final tiles = find.descendant(of: collection, matching: find.byType(AspectRatio));
      expect(tiles, findsNWidgets(count));
      for (final tile in tester.widgetList<AspectRatio>(tiles)) {
        expect(tile.aspectRatio, 1);
      }
      final firstSize = tester.getSize(tiles.at(0));
      if (count.isOdd) {
        expect(firstSize.width, 320);
      } else {
        expect(firstSize.width, closeTo(157, 0.01));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets("renders square metadata fallback with bounded overlay text", (tester) async {
    const filename =
        "a-very-long-attachment-filename-that-needs-to-stay-on-one-line-and-ellipsis-in-the-square-grid.png";
    await tester.pumpWidget(
      _app(
        child: const SizedBox(
          width: 180,
          child: AttachmentCollectionWidget(
            sessionId: "session-1",
            attachments: [MessageAttachment.metadata(mime: "image/png", filename: filename)],
          ),
        ),
      ),
    );

    final tile = find.descendant(
      of: find.byType(AttachmentCollectionWidget),
      matching: find.byType(AspectRatio),
    );
    expect(tester.getSize(tile), const Size(180, 180));
    final filenameText = tester.widget<Text>(find.text(filename));
    expect(filenameText.maxLines, 1);
    expect(filenameText.overflow, TextOverflow.ellipsis);
    expect(find.text("image/png"), findsOneWidget);
  });

  testWidgets("unknown attachments do not occupy collection slots", (tester) async {
    const filename = "visible.png";
    await tester.pumpWidget(
      _app(
        child: const SizedBox(
          width: 320,
          child: AttachmentCollectionWidget(
            sessionId: "session-1",
            attachments: [
              MessageAttachment.metadata(mime: "image/png", filename: filename),
              MessageAttachment.unknown(),
            ],
          ),
        ),
      ),
    );

    final tile = find.descendant(
      of: find.byType(AttachmentCollectionWidget),
      matching: find.byType(AspectRatio),
    );
    expect(tile, findsOneWidget);
    expect(tester.getSize(tile).width, 320);
  });

  testWidgets("fallback metadata is announced once", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(
          sessionId: "session-1",
          attachment: MessageAttachment.metadata(mime: "application/pdf", filename: "report.pdf"),
        ),
      ),
    );

    expect(find.bySemanticsLabel("report.pdf"), findsOneWidget);
    semantics.dispose();
  });

  testWidgets("extreme text scaling keeps metadata without overflowing", (tester) async {
    await tester.pumpWidget(
      _app(
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(3)),
          child: SizedBox(
            width: 140,
            child: FilePartWidget(
              sessionId: "session-1",
              attachment: MessageAttachment.metadata(
                mime: "image/png",
                filename: "scaled.png",
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text("scaled.png"), findsOneWidget);
    expect(find.text("image/png"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("dark metadata overlay keeps secondary text light", (tester) async {
    await tester.pumpWidget(
      _app(
        themeMode: ThemeMode.dark,
        child: const FilePartWidget(
          sessionId: "session-1",
          attachment: MessageAttachment.metadata(mime: "image/png", filename: "dark.png"),
        ),
      ),
    );

    final details = tester.widget<Text>(find.text("image/png"));
    expect(details.style?.color, PregoDesignSystem.dark.colors.textWhite.withValues(alpha: 0.7));
  });

  testWidgets("uses a static loading indicator when reduced motion is enabled", (tester) async {
    const attachment = MessageAttachment.storedImage(
      attachmentId: "loading",
      bridgeId: "bridge-1",
      mime: "image/png",
      filename: "loading.png",
      byteLength: 8,
    );
    when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _authUser));
    when(
      () => thumbnailStorage.read(
        scope: any(named: "scope"),
        key: any(named: "key"),
      ),
    ).thenAnswer(
      (_) async => null,
    );
    when(
      () => sessionApi.getAttachment(
        sessionId: "session-1",
        attachmentId: "loading",
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer((_) => Completer<ApiResponse<SessionAttachmentResponse>>().future);
    await GetIt.instance.unregister<MessageImageRepository>();
    GetIt.instance.registerSingleton<MessageImageRepository>(
      MessageImageRepository(
        api: MessageImageApi(client: MockClient((_) async => throw StateError("unexpected"))),
        sessionApi: sessionApi,
        authSession: authSession,
        attachmentThumbnailStorage: thumbnailStorage,
      ),
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(
          child: const SizedBox(
            width: 160,
            child: FilePartWidget(sessionId: "session-1", attachment: attachment),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(PregoActivityIndicator), findsOneWidget);
    expect(find.byType(AspectRatio), findsOneWidget);
    expect(find.text("image/png / 8 bytes"), findsOneWidget);
  });

  testWidgets("failed raster tile exposes retry semantics and retries the request", (tester) async {
    var requests = 0;
    await GetIt.instance.unregister<MessageImageRepository>();
    GetIt.instance.registerSingleton<MessageImageRepository>(
      MessageImageRepository(
        api: MessageImageApi(
          client: MockClient((_) async {
            requests++;
            return http.Response("failed", 500);
          }),
        ),
        sessionApi: sessionApi,
        authSession: authSession,
        attachmentThumbnailStorage: thumbnailStorage,
      ),
    );
    const attachment = MessageAttachment.remoteUrl(
      mime: "image/png",
      url: "https://files.example.com/retry.png",
      filename: "retry.png",
    );
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(
        child: const SizedBox(
          width: 160,
          child: FilePartWidget(sessionId: "session-1", attachment: attachment),
        ),
      ),
    );
    await tester.runAsync(() async {
      while (requests < 1) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pump();
    expect(requests, 1);
    expect(find.text("Retry"), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(tester.getSemantics(find.text("Retry")).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    await tester.tapAt(const Offset(12, 12));
    await tester.pump();
    verify(
      () => urlLauncher.launch(Uri.parse("https://files.example.com/retry.png"), mode: UrlLaunchMode.externalApp),
    ).called(1);

    await tester.tap(find.text("Retry"));
    await tester.runAsync(() async {
      while (requests < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    await tester.pump();
    expect(requests, 2);
    semantics.dispose();
  });

  testWidgets("stored viewer decodes before swapping or enabling actions and evicts on close", (tester) async {
    final repository = _MockMessageImageRepository();
    final original = Completer<MessageImageLoadResult>();
    var originalRequests = 0;
    const attachment = MessageAttachment.storedImage(
      attachmentId: "attachment-1",
      bridgeId: "bridge-1",
      mime: "image/png",
      filename: "stored.png",
      byteLength: 68,
    );
    when(() => repository.canLoad(attachment: attachment)).thenReturn(true);
    when(() => repository.canLoadOriginal(attachment: attachment)).thenReturn(true);
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: attachment,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer(
      (_) async => MessageImageLoadSuccess(
        bytes: Uint8List.fromList(base64Decode(_pngBase64)),
        mime: "image/png",
        actionFilename: "stored.png",
        originalUri: null,
      ),
    );
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: attachment,
        rendition: SessionAttachmentRendition.original,
      ),
    ).thenAnswer((_) {
      originalRequests++;
      return original.future;
    });
    await GetIt.instance.unregister<MessageImageRepository>();
    GetIt.instance.registerSingleton<MessageImageRepository>(repository);

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _finishAsyncDecode(tester: tester);
    expect(originalRequests, 0);

    final preview = tester.widget<Image>(find.byKey(FilePartWidget.previewImageKey));
    await tester.runAsync(
      () => precacheImage(
        preview.image,
        tester.element(find.byKey(FilePartWidget.previewImageKey)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FilePartWidget.previewTapTargetKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(originalRequests, 1);
    final thumbnailImage = tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey));
    final transformationController = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    transformationController.value = Matrix4.diagonal3Values(2, 2, 1);
    expect(find.byIcon(Icons.content_copy), findsNothing);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsNothing);

    final originalBytes = Uint8List.fromList(base64Decode(_pngBase64));
    original.complete(
      MessageImageLoadSuccess(
        bytes: originalBytes,
        mime: "image/png",
        actionFilename: "stored.png",
        originalUri: null,
      ),
    );
    await tester.pump();

    expect(tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey)).image, same(thumbnailImage.image));
    expect(find.byIcon(Icons.content_copy), findsNothing);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsNothing);

    await _finishAsyncDecode(tester: tester);

    final originalImage = tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey));
    final originalProvider = originalImage.image as MemoryImage;
    expect(originalProvider.bytes, same(originalBytes));
    expect(transformationController.value.getMaxScaleOnAxis(), 2);
    expect(
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController,
      same(transformationController),
    );
    expect(find.byIcon(Icons.content_copy), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(await originalProvider.obtainCacheStatus(configuration: ImageConfiguration.empty), isNotNull);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final popFlight = tester.widget<Image>(find.byKey(ImageAttachmentViewer.flightCropImageKey));
    expect(popFlight.image, same(thumbnailImage.image));

    await tester.pumpAndSettle();

    final cubit = tester.element(find.byKey(FilePartWidget.previewTapTargetKey)).read<MessageImageCubit>();
    expect(cubit.state.original, isA<MessageImageOriginalAvailable>());
    final evictedStatus = await originalProvider.obtainCacheStatus(configuration: ImageConfiguration.empty);
    expect(evictedStatus?.pending, isFalse);
    expect(evictedStatus?.keepAlive, isFalse);
    expect(evictedStatus?.live, isFalse);
  });

  testWidgets("stored viewer retains thumbnail and exposes accessible retry after request failure", (tester) async {
    final repository = _MockMessageImageRepository();
    var originalRequests = 0;
    const attachment = MessageAttachment.storedImage(
      attachmentId: "attachment-1",
      bridgeId: "bridge-1",
      mime: "image/png",
      filename: "stored.png",
      byteLength: 68,
    );
    when(() => repository.canLoad(attachment: attachment)).thenReturn(true);
    when(() => repository.canLoadOriginal(attachment: attachment)).thenReturn(true);
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: attachment,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer(
      (_) async => MessageImageLoadSuccess(
        bytes: Uint8List.fromList(base64Decode(_pngBase64)),
        mime: "image/png",
        actionFilename: "stored.png",
        originalUri: null,
      ),
    );
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: attachment,
        rendition: SessionAttachmentRendition.original,
      ),
    ).thenAnswer((_) async {
      originalRequests++;
      return const MessageImageLoadRejected();
    });
    await GetIt.instance.unregister<MessageImageRepository>();
    GetIt.instance.registerSingleton<MessageImageRepository>(repository);

    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _openImageViewer(tester: tester);

    final thumbnailProvider = tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey)).image;
    expect(find.text("Couldn’t load the original image."), findsOneWidget);
    expect(find.byIcon(Icons.content_copy), findsNothing);
    expect(originalRequests, 1);
    expect(
      tester.getSemantics(find.text("Retry original")).getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.tap(find.widgetWithText(TextButton, "Retry original"));
    await tester.pumpAndSettle();

    expect(originalRequests, 2);
    expect(tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey)).image, same(thumbnailProvider));
    semantics.dispose();
  });

  testWidgets("stored viewer retains thumbnail and disables actions when original decode fails", (tester) async {
    final repository = _MockMessageImageRepository();
    var originalRequests = 0;
    const attachment = MessageAttachment.storedImage(
      attachmentId: "attachment-1",
      bridgeId: "bridge-1",
      mime: "image/png",
      filename: "stored.png",
      byteLength: 68,
    );
    when(() => repository.canLoad(attachment: attachment)).thenReturn(true);
    when(() => repository.canLoadOriginal(attachment: attachment)).thenReturn(true);
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: attachment,
        rendition: SessionAttachmentRendition.thumbnail,
      ),
    ).thenAnswer(
      (_) async => MessageImageLoadSuccess(
        bytes: Uint8List.fromList(base64Decode(_pngBase64)),
        mime: "image/png",
        actionFilename: "stored.png",
        originalUri: null,
      ),
    );
    when(
      () => repository.load(
        sessionId: "session-1",
        attachment: attachment,
        rendition: SessionAttachmentRendition.original,
      ),
    ).thenAnswer((_) async {
      originalRequests++;
      return MessageImageLoadSuccess(
        bytes: Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]),
        mime: "image/png",
        actionFilename: "stored.png",
        originalUri: null,
      );
    });
    await GetIt.instance.unregister<MessageImageRepository>();
    GetIt.instance.registerSingleton<MessageImageRepository>(repository);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _openImageViewer(tester: tester);

    final thumbnailProvider = tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey)).image;
    expect(originalRequests, 1);
    expect(find.text("Couldn’t load the original image."), findsOneWidget);
    expect(find.text("Retry original"), findsOneWidget);
    expect(find.byIcon(Icons.content_copy), findsNothing);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
    expect(tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey)).image, same(thumbnailProvider));
    expect(
      tester.getSemantics(find.text("Retry original")).getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    await tester.tap(find.widgetWithText(TextButton, "Retry original"));
    await _finishAsyncDecode(tester: tester);

    expect(originalRequests, 2);
    expect(find.text("Couldn’t load the original image."), findsOneWidget);
    expect(tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey)).image, same(thumbnailProvider));
    semantics.dispose();
  });

  testWidgets("opens inline images in a zoomable Hero viewer using the same provider", (tester) async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
      filename: "why-needed.png",
    );

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _finishAsyncDecode(tester: tester);

    final preview = tester.widget<Image>(find.byKey(FilePartWidget.previewImageKey));
    await tester.runAsync(
      () => precacheImage(
        preview.image,
        tester.element(find.byKey(FilePartWidget.previewImageKey)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.broken_image), findsNothing);
    expect(
      tester.widget<GestureDetector>(find.byKey(FilePartWidget.previewTapTargetKey)).onTap,
      isNotNull,
    );
    await tester.tap(find.byKey(FilePartWidget.previewTapTargetKey));
    await tester.pumpAndSettle();

    expect(find.byType(ImageAttachmentViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byIcon(Icons.content_copy), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.text("why-needed.png"), findsOneWidget);
    final fullscreen = tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey));
    expect(identical(fullscreen.image, preview.image), isTrue);
    final memoryImage = (preview.image as ResizeImage).imageProvider as MemoryImage;

    await tester.tap(find.byIcon(Icons.content_copy));
    await tester.pump();

    expect(identical(imageClipboard.copiedBytes, memoryImage.bytes), isTrue);
    expect(find.text("Image copied to clipboard"), findsOneWidget);
  });

  testWidgets("Hero flight reveals the contained image from the square crop", (tester) async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: _widePngBase64,
      filename: "flight.png",
    );
    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _finishAsyncDecode(tester: tester);
    final preview = tester.widget<Image>(find.byKey(FilePartWidget.previewImageKey));
    await tester.runAsync(
      () => precacheImage(
        preview.image,
        tester.element(find.byKey(FilePartWidget.previewImageKey)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(FilePartWidget.previewTapTargetKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));

    final crop = find.byKey(ImageAttachmentViewer.flightCropImageKey);
    final full = find.byKey(ImageAttachmentViewer.flightFullImageKey);
    expect(tester.widget<Image>(crop).fit, BoxFit.cover);
    expect(tester.widget<Image>(full).fit, BoxFit.contain);
    final cropOpacity = tester.widget<Opacity>(find.ancestor(of: crop, matching: find.byType(Opacity))).opacity;
    final fullOpacity = tester.widget<Opacity>(find.ancestor(of: full, matching: find.byType(Opacity))).opacity;
    expect(cropOpacity, isPositive);
    expect(cropOpacity, lessThan(1));
    expect(fullOpacity, isPositive);
    expect(fullOpacity, lessThan(1));
    expect(
      cropOpacity + fullOpacity,
      closeTo(1, 0.001),
    );

    await tester.pumpAndSettle();
    expect(crop, findsNothing);
    expect(full, findsNothing);
    expect(tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey)).fit, BoxFit.contain);
  });

  testWidgets("reduced motion skips image viewer route transitions", (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(
          child: const FilePartWidget(
            sessionId: "session-1",
            attachment: MessageAttachment.inlineImage(
              mime: "image/png",
              base64: _pngBase64,
              filename: "reduced-motion.png",
            ),
          ),
        ),
      ),
    );

    await _openImageViewer(tester: tester);

    final route = ModalRoute.of(tester.element(find.byType(ImageAttachmentViewer)))! as PageRoute<void>;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });

  testWidgets("cross-fades image replacement without resetting viewer state", (tester) async {
    final thumbnailProvider = MemoryImage(Uint8List.fromList(base64Decode(_pngBase64)));
    final originalProvider = MemoryImage(Uint8List.fromList(base64Decode(_pngBase64)));
    final heroTag = UniqueKey();

    Widget viewer({required ImageProvider provider}) => _app(
      child: ImageAttachmentViewer(
        image: ViewOnlyMessageImage(provider: provider, originalUri: null),
        flightImageProvider: provider,
        heroPresentation: ImageAttachmentHeroPresentation.cropped,
        filename: "swap.png",
        heroTag: heroTag,
        originalPresentation: ImageAttachmentOriginalPresentation.idle,
        onRetryOriginal: null,
      ),
    );

    await tester.pumpWidget(viewer(provider: thumbnailProvider));
    await tester.pumpAndSettle();
    final transformationController = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController;

    await tester.pumpWidget(viewer(provider: originalProvider));
    await tester.pump();

    final swappingImages = tester.widgetList<Image>(find.byKey(ImageAttachmentViewer.imageKey)).toList();
    expect(swappingImages, hasLength(2));
    expect(swappingImages.map((image) => image.image), containsAll([thumbnailProvider, originalProvider]));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && (widget.properties.image ?? false) && widget.properties.label == "swap.png",
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController,
      same(transformationController),
    );

    await tester.pumpAndSettle();
    final displayed = tester.widget<Image>(find.byKey(ImageAttachmentViewer.imageKey));
    expect(displayed.image, same(originalProvider));
  });

  testWidgets("session back closes the root image viewer without leaving the session", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
      filename: "image.png",
    );
    final rootNavigatorKey = GlobalKey<NavigatorState>();
    final sessionNavigatorKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: "/sessions/chat",
      routes: [
        ShellRoute(
          navigatorKey: sessionNavigatorKey,
          builder: (_, _, child) => Scaffold(
            body: Row(
              children: [
                const SizedBox(
                  width: 300,
                  child: Center(child: Text("Session list pane")),
                ),
                Expanded(child: child),
              ],
            ),
          ),
          routes: [
            GoRoute(
              path: "/sessions",
              builder: (_, _) => const Scaffold(body: Text("Session list route")),
              routes: [
                GoRoute(
                  path: "chat",
                  builder: (_, _) => const Scaffold(
                    body: FilePartWidget(sessionId: "session-1", attachment: attachment),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await _openImageViewer(tester: tester);
    final sessionRoute = ModalRoute.of(tester.element(find.byKey(FilePartWidget.previewTapTargetKey)))!;

    expect(find.byType(ImageAttachmentViewer), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, "/sessions/chat");
    final viewerRoute = ModalRoute.of(tester.element(find.byType(ImageAttachmentViewer)))!;
    expect(viewerRoute.navigator, same(rootNavigatorKey.currentState));
    expect(viewerRoute.opaque, isFalse);
    expect(tester.getSize(find.byType(ImageAttachmentViewer)), const Size(1024, 800));
    expect(sessionRoute.willHandlePopInternally, isTrue);

    expect(await sessionNavigatorKey.currentState!.maybePop(), isTrue);
    await tester.pumpAndSettle();

    expect(find.byType(ImageAttachmentViewer), findsNothing);
    expect(find.byKey(FilePartWidget.previewTapTargetKey), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, "/sessions/chat");
    expect(sessionRoute.willHandlePopInternally, isFalse);

    expect(await sessionNavigatorKey.currentState!.maybePop(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text("Session list route"), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, "/sessions");
  });

  testWidgets("free-form image drag follows the pointer, snaps back, or dismisses", (tester) async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
      filename: "image.png",
    );
    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _openImageViewer(tester: tester);
    final viewer = find.byType(ImageAttachmentViewer);
    final initialCenter = tester.getCenter(find.byKey(ImageAttachmentViewer.imageKey));

    final gesture = await tester.startGesture(initialCenter);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(20, 15));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(20, 15));
    await tester.pump();

    final draggedCenter = tester.getCenter(find.byKey(ImageAttachmentViewer.imageKey));
    expect(draggedCenter.dx, greaterThan(initialCenter.dx));
    expect(draggedCenter.dy, greaterThan(initialCenter.dy));

    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(viewer, findsOneWidget);
    expect(
      (tester.getCenter(find.byKey(ImageAttachmentViewer.imageKey)) - initialCenter).distance,
      lessThan(0.01),
    );

    await tester.timedDrag(viewer, const Offset(200, 0), const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(viewer, findsNothing);
    expect(find.byKey(FilePartWidget.previewTapTargetKey), findsOneWidget);
  });

  testWidgets("fast drag back to center does not dismiss the viewer", (tester) async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
      filename: "image.png",
    );
    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _openImageViewer(tester: tester);
    final viewer = find.byType(ImageAttachmentViewer);
    final image = find.byKey(ImageAttachmentViewer.imageKey);
    final initialCenter = tester.getCenter(image);

    final gesture = await tester.startGesture(initialCenter);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(30, 0), timeStamp: const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(30, 0), timeStamp: const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveBy(const Offset(-10, 0), timeStamp: const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1));
    await gesture.moveBy(const Offset(-10, 0), timeStamp: const Duration(milliseconds: 401));
    await tester.pump(const Duration(milliseconds: 1));
    await gesture.moveBy(const Offset(-10, 0), timeStamp: const Duration(milliseconds: 402));
    await tester.pump(const Duration(milliseconds: 1));

    expect((tester.getCenter(image) - initialCenter).distance, lessThan(0.01));

    await gesture.up(timeStamp: const Duration(milliseconds: 403));
    await tester.pumpAndSettle();

    expect(viewer, findsOneWidget);
  });

  testWidgets("double tap toggles zoom and disables drag dismissal while zoomed", (tester) async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
      filename: "image.png",
    );
    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _openImageViewer(tester: tester);
    final viewer = find.byType(ImageAttachmentViewer);
    final interactiveViewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final transformationController = interactiveViewer.transformationController!;

    await _doubleTap(tester: tester, finder: viewer);

    expect(transformationController.value.getMaxScaleOnAxis(), closeTo(2.5, 0.01));
    await tester.timedDrag(viewer, const Offset(0, 200), const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(viewer, findsOneWidget);

    await _doubleTap(tester: tester, finder: viewer);

    expect(transformationController.value.getMaxScaleOnAxis(), closeTo(1, 0.01));
    await tester.timedDrag(viewer, const Offset(0, 200), const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(viewer, findsNothing);
  });

  testWidgets("omits the image title when attachment metadata has no filename", (tester) async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
      filename: null,
    );

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _finishAsyncDecode(tester: tester);
    final preview = tester.widget<Image>(find.byKey(FilePartWidget.previewImageKey));
    await tester.runAsync(
      () => precacheImage(
        preview.image,
        tester.element(find.byKey(FilePartWidget.previewImageKey)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FilePartWidget.previewTapTargetKey));
    await tester.pumpAndSettle();

    expect(find.text("image.png"), findsNothing);
    expect(find.text("Unknown file"), findsNothing);
    await tester.tap(find.byIcon(Icons.download_outlined));
    await tester.pump();

    expect(imageSaver.savedFilename, "image.png");
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
        child: ImageAttachmentViewer(
          image: image,
          flightImageProvider: image.provider,
          heroPresentation: ImageAttachmentHeroPresentation.contained,
          filename: "../../unsafe.exe",
          heroTag: UniqueKey(),
          originalPresentation: ImageAttachmentOriginalPresentation.idle,
          onRetryOriginal: null,
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

    expect(imageSaver.savedFilename, "unsafe.png");
    expect(identical(imageSaver.savedBytes, bytes), isTrue);
  });

  testWidgets("opens a safe remote attachment only after a tap", (tester) async {
    const attachment = MessageAttachment.remoteUrl(
      mime: "application/pdf",
      url: "https://files.example.com/report.pdf",
      filename: "report.pdf",
    );

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );

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
              base64Decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
              ),
              200,
            );
          }),
        ),
        sessionApi: sessionApi,
        authSession: authSession,
        attachmentThumbnailStorage: thumbnailStorage,
      ),
    );
    const attachment = MessageAttachment.remoteUrl(
      mime: "image/png",
      url: "https://files.example.com/image.png",
      filename: "image.png",
    );

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _finishAsyncDecode(tester: tester);
    await tester.pump();

    expect(find.byKey(FilePartWidget.previewImageKey), findsOneWidget);
    expect(requests, 1);
    verifyNever(() => urlLauncher.launch(any(), mode: any(named: "mode")));
  });

  testWidgets("corrupt image bytes expose retry without opening the viewer", (tester) async {
    var requests = 0;
    await GetIt.instance.unregister<MessageImageRepository>();
    GetIt.instance.registerSingleton<MessageImageRepository>(
      MessageImageRepository(
        api: MessageImageApi(
          client: MockClient(
            (_) async {
              requests++;
              return http.Response.bytes(
                Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
                200,
              );
            },
          ),
        ),
        sessionApi: sessionApi,
        authSession: authSession,
        attachmentThumbnailStorage: thumbnailStorage,
      ),
    );
    const attachment = MessageAttachment.remoteUrl(
      mime: "image/png",
      url: "https://files.example.com/corrupt.png",
      filename: "corrupt.png",
    );

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _finishAsyncDecode(tester: tester);
    await tester.tap(find.byKey(FilePartWidget.previewTapTargetKey), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(ImageAttachmentViewer), findsNothing);
    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(find.text("Retry"), findsOneWidget);
    final requestsAfterTap = requests;
    await tester.tap(find.text("Retry"));
    await tester.runAsync(() async {
      while (requests <= requestsAfterTap) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    expect(requests, greaterThan(requestsAfterTap));
    expect(tester.takeException(), isNull);
  });

  testWidgets("does not launch unsafe remote schemes", (tester) async {
    const attachment = MessageAttachment.remoteUrl(
      mime: "application/pdf",
      url: "intent://open/report.pdf",
      filename: "report.pdf",
    );

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await tester.tap(find.text("report.pdf"), warnIfMissed: false);

    verifyNever(() => urlLauncher.launch(any(), mode: any(named: "mode")));
  });

  testWidgets("does not render a hardcoded MIME fallback", (tester) async {
    const attachment = MessageAttachment.metadata(
      mime: " ",
      filename: "unknown.bin",
    );

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );

    expect(find.text("unknown.bin"), findsOneWidget);
    expect(find.text("application/octet-stream"), findsNothing);
  });

  testWidgets("degrades malformed inline data to a metadata tile", (tester) async {
    const attachment = MessageAttachment.inlineImage(
      mime: "image/png",
      base64: "%%%",
      filename: "broken.png",
    );

    await tester.pumpWidget(
      _app(
        child: const FilePartWidget(sessionId: "session-1", attachment: attachment),
      ),
    );
    await _finishAsyncDecode(tester: tester);

    expect(find.text("broken.png"), findsOneWidget);
    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(find.text("Retry"), findsNothing);
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

    await tester.pumpWidget(
      _app(
        child: const ToolPartWidget(part: part),
      ),
    );

    expect(find.text("screenshot.png"), findsOneWidget);
  });

  testWidgets("renders normalized user file attachments", (tester) async {
    const message = MessageWithParts(
      info: Message.user(
        promptId: null,
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

    await tester.pumpWidget(
      _app(
        child: const UserMessageCard(message: message),
      ),
    );

    expect(find.text("notes.txt"), findsOneWidget);
  });
}
