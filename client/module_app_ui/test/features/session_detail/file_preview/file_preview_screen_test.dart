import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/rendering.dart" show RenderParagraph;
import "package:flutter/services.dart" show MethodCall, SystemChannels;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:markdown/markdown.dart" as md;
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:pdfrx/pdfrx.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/file_preview/file_preview_screen.dart";
import "package:sesori_app_ui/src/features/session_detail/file_preview/file_reference_code_syntax.dart";
import "package:sesori_app_ui/src/widgets/chat_link.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";
import "package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart";

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

class _MockFilePreviewCubit() extends MockCubit<FilePreviewState> implements FilePreviewCubit;

class _MockFilePreviewRepository() extends Mock implements FilePreviewRepository;

class _MockImageSaver() extends Mock implements ImageSaver;

class _MockImageClipboard() extends Mock implements ImageClipboard;

class _MockImageSharer() extends Mock implements ImageSharer;

/// Stands in for the native web view, recording what the preview asks of it.
class _FakeWebViewPlatform() extends WebViewPlatform {
  final controllers = <_FakeWebViewController>[];

  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) {
    final controller = _FakeWebViewController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) =>
      _FakeNavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      _FakeWebViewWidget(params);
}

class _FakeWebViewController(super.params) extends PlatformWebViewController {
  this : super.implementation();

  final loadedHtml = <String>[];
  JavaScriptMode? javaScriptMode;
  PlatformNavigationDelegate? navigationDelegate;

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async => loadedHtml.add(html);

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async => this.javaScriptMode = javaScriptMode;

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async => navigationDelegate = handler;

  /// What the page's navigation delegate decides for [url].
  Future<NavigationDecision> decide({required String url, required bool isMainFrame}) async {
    final callback = switch (navigationDelegate) {
      _FakeNavigationDelegate(:final onNavigationRequest?) => onNavigationRequest,
      _ => throw StateError("no navigation request handler"),
    };
    return await callback(NavigationRequest(url: url, isMainFrame: isMainFrame));
  }

  /// Tells the page's navigation delegate that the main frame started [url].
  void startPage({required String url}) {
    final callback = switch (navigationDelegate) {
      _FakeNavigationDelegate(:final onPageStarted?) => onPageStarted,
      _ => throw StateError("no page started handler"),
    };
    callback(url);
  }

  /// Tells the page's navigation delegate that the main frame finished [url].
  void finishPage({required String url}) {
    final callback = switch (navigationDelegate) {
      _FakeNavigationDelegate(:final onPageFinished?) => onPageFinished,
      _ => throw StateError("no page finished handler"),
    };
    callback(url);
  }
}

class _FakeNavigationDelegate(super.params) extends PlatformNavigationDelegate {
  this : super.implementation();

  NavigationRequestCallback? onNavigationRequest;
  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async => this.onPageFinished = onPageFinished;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async =>
      this.onNavigationRequest = onNavigationRequest;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async => this.onPageStarted = onPageStarted;
}

class _FakeWebViewWidget(super.params) extends PlatformWebViewWidget {
  this : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand(key: Key("fake-web-view"));
}

/// A 1×1 transparent PNG.
final _png = base64Decode(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
);

Future<bool> _ignoreLink({required Uri url, required UrlLaunchMode mode}) async => false;

Widget _app({
  required FilePreviewCubitFactory createFilePreviewCubit,
  required ExternalLinkOpener openExternalLink,
  required Widget child,
}) => MaterialApp(
  theme: ThemeData(extensions: [PregoDesignSystem.light]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: SessionDetailPresentationScope(
    openHarnessSettings: () {},
    openBridgeSettings: () {},
    messageImageRepository: () => throw UnimplementedError(),
    imageSaver: _MockImageSaver.new,
    imageClipboard: _MockImageClipboard.new,
    imageSharer: _MockImageSharer.new,
    sessionRepository: () => throw UnimplementedError(),
    createPendingFormCubit: ({required requestId, required sessionId}) => throw UnimplementedError(),
    createFilePreviewCubit: createFilePreviewCubit,
    createExternalActionCubit: ({required requestId, required sessionId}) => throw UnimplementedError(),
    canShareImages: false,
    openExternalLink: openExternalLink,
    openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
    child: Scaffold(body: child),
  ),
);

class _MockPdfViewerController() extends Mock implements PdfViewerController;

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FileReference reference,
  required FilePreviewState state,
  required ExternalLinkOpener openExternalLink,
}) async {
  final cubit = _MockFilePreviewCubit();
  whenListen(cubit, const Stream<FilePreviewState>.empty(), initialState: state);
  await tester.pumpWidget(
    _app(
      createFilePreviewCubit: ({required reference}) => cubit,
      openExternalLink: openExternalLink,
      child: BlocProvider<FilePreviewCubit>.value(
        value: cubit,
        child: FilePreviewScreen(reference: reference, onClose: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TextSpan? _spanWithText(WidgetTester tester, String text) {
  TextSpan? found;
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    widget.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) found = span;
      return found == null;
    });
  }
  return found;
}

RenderParagraph _paragraphStartingWith(WidgetTester tester, String text) => tester
    .renderObjectList<RenderParagraph>(find.byType(RichText))
    .singleWhere((paragraph) => paragraph.text.toPlainText().startsWith(text));

void main() {
  group("FileReferenceCodeSyntax", () {
    List<md.Node> parse(String text) =>
        md.Document(inlineSyntaxes: sessionMarkdownInlineSyntaxes, encodeHtml: false).parseInline(text);

    test("links inline code that reads as a path", () {
      final nodes = parse("See `lib/main.dart:3` now");
      final link = nodes.whereType<md.Element>().single;
      expect(link.tag, "a");
      expect(link.attributes["href"], "lib/main.dart:3");
      expect(link.textContent, "lib/main.dart:3");
    });

    test("leaves other inline code alone", () {
      final element = parse("Call `foo()` or `v1.2`").whereType<md.Element>().toList();
      expect(element.map((e) => e.tag), ["code", "code"]);
    });

    test("keeps the link a path is the text of", () {
      final link = parse("[`lib/a.dart`](https://example.com/a)").whereType<md.Element>().single;
      expect(link.attributes["href"], "https://example.com/a");
      expect(link.children?.whereType<md.Element>().single.tag, "code");
    });
  });

  testWidgets("a tap on a path in a text part opens its preview", (tester) async {
    const reference = FileReference(absolutePath: "/repo/lib/main.dart", line: 2);
    final sessionCubit = _MockSessionDetailCubit();
    when(() => sessionCubit.openFileReference(raw: "lib/main.dart:2")).thenAnswer((_) async => reference);
    final repository = _MockFilePreviewRepository();
    when(() => repository.load(path: "/repo/lib/main.dart")).thenAnswer(
      (_) async => const FilePreviewTextContent(content: "one\ntwo\nthree"),
    );

    await tester.pumpWidget(
      _app(
        createFilePreviewCubit: ({required reference}) =>
            FilePreviewCubit(repository: repository, reference: reference),
        openExternalLink: _ignoreLink,
        child: BlocProvider<SessionDetailCubit>.value(
          value: sessionCubit,
          child: const TextPartWidget(text: "Look at `lib/main.dart:2` please"),
        ),
      ),
    );
    final link = find.byType(ChatLink);
    expect(tester.widget<ChatLink>(link).presentation.label, "main.dart (line 2)");
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.byType(FilePreviewScreen), findsOneWidget);
    expect(find.text("main.dart"), findsOneWidget);
    expect(find.text("/repo/lib/main.dart"), findsOneWidget);
    expect(_spanWithText(tester, "two"), isNotNull);

    await tester.tap(find.byKey(const Key("file-preview-close")));
    await tester.pumpAndSettle();
    expect(find.byType(FilePreviewScreen), findsNothing);
  });

  group("FilePreviewScreen", () {
    testWidgets("shows text with line numbers", (tester) async {
      await _pumpScreen(
        tester,
        reference: const FileReference(absolutePath: "/repo/notes.txt", line: 2),
        state: const FilePreviewShowsText(content: "alpha\nbeta"),
        openExternalLink: _ignoreLink,
      );
      expect(find.text("1"), findsOneWidget);
      expect(find.text("2"), findsOneWidget);
      expect(_spanWithText(tester, "beta"), isNotNull);
    });

    testWidgets("colours its header buttons like the app's other screens", (tester) async {
      await _pumpScreen(
        tester,
        reference: const FileReference(absolutePath: "/repo/README.md", line: null),
        state: const FilePreviewShowsText(content: "# Title"),
        openExternalLink: _ignoreLink,
      );
      final colors = PregoDesignSystem.light.colors;
      Color? iconColor(Key key) =>
          IconTheme.of(tester.element(find.descendant(of: find.byKey(key), matching: find.byType(Icon)))).color;
      // Like every back button and the image viewer's close button.
      expect(iconColor(const Key("file-preview-close")), colors.textPrimary);
      // Like the Copy button beside it.
      expect(iconColor(const Key("file-preview-source-toggle")), colors.textSecondary);
    });

    testWidgets("renders Markdown and toggles to its source", (tester) async {
      await _pumpScreen(
        tester,
        reference: const FileReference(absolutePath: "/repo/README.md", line: null),
        state: const FilePreviewShowsText(content: "# Title"),
        openExternalLink: _ignoreLink,
      );
      expect(find.text("Title"), findsOneWidget);

      await tester.tap(find.byKey(const Key("file-preview-source-toggle")));
      await tester.pumpAndSettle();
      expect(_spanWithText(tester, "# Title"), isNotNull);
    });

    testWidgets("cuts a very long line short but copies it whole", (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call case MethodCall(method: "Clipboard.setData", arguments: {"text": final String text})) copied = text;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      // Over the highlighting limit, so the lines are plain.
      final content = "${"a" * 250000}\nshort";
      await _pumpScreen(
        tester,
        reference: const FileReference(absolutePath: "/repo/page.txt", line: null),
        state: FilePreviewShowsText(content: content),
        openExternalLink: _ignoreLink,
      );
      expect(_spanWithText(tester, "${"a" * 10000}…"), isNotNull);
      expect(_spanWithText(tester, "short"), isNotNull);

      await tester.tap(find.byTooltip("Copy"));
      await tester.pump();
      expect(copied, content);
    });

    testWidgets("fits a large file's rows to the platform's text spacing", (tester) async {
      final dispatcher = tester.platformDispatcher
        ..letterSpacingOverrideTestValue = 2
        ..wordSpacingOverrideTestValue = 6
        ..lineHeightScaleFactorOverrideTestValue = 2;
      addTearDown(dispatcher.clearLetterSpacingOverrideTestValue);
      addTearDown(dispatcher.clearWordSpacingOverrideTestValue);
      addTearDown(dispatcher.clearLineHeightScaleFactorOverrideTestValue);
      // Under the line limit, in a file over the highlighting limit.
      final line = List.filled(1999, "word").join(" ");
      await _pumpScreen(
        tester,
        reference: const FileReference(absolutePath: "/repo/page.txt", line: null),
        state: FilePreviewShowsText(content: "$line\n${List.filled(40000, "filler").join("\n")}"),
        openExternalLink: _ignoreLink,
      );
      final row = _paragraphStartingWith(tester, "word word");
      expect(row.size.width, greaterThanOrEqualTo(row.getMaxIntrinsicWidth(double.infinity)));
      expect(row.size.height, greaterThanOrEqualTo(row.getMaxIntrinsicHeight(row.size.width)));
    });

    testWidgets("keeps a large file's cut ASCII row at its own width", (tester) async {
      await _pumpScreen(
        tester,
        reference: const FileReference(absolutePath: "/repo/page.txt", line: null),
        state: FilePreviewShowsText(content: "${"a" * 250000}\nshort"),
        openExternalLink: _ignoreLink,
      );
      final row = _paragraphStartingWith(tester, "aaaa");
      final textWidth = row.getMaxIntrinsicWidth(double.infinity);
      expect(row.size.width, greaterThanOrEqualTo(textWidth));
      expect(row.size.width, lessThan(textWidth * 1.5));
    });

    testWidgets("cuts a very long highlighted line short", (tester) async {
      await _pumpScreen(
        tester,
        reference: const FileReference(absolutePath: "/repo/data.dart", line: null),
        state: FilePreviewShowsText(content: "final data = '${"x" * 25000}';\nvoid main() {}"),
        openExternalLink: _ignoreLink,
      );
      final rows = [
        for (final text in tester.widgetList<RichText>(find.byType(RichText)))
          if (text.text.toPlainText().startsWith("final data")) text.text.toPlainText(),
      ];
      expect(rows, hasLength(1));
      expect(rows.single, hasLength(10001));
      expect(rows.single, endsWith("x…"));
    });

    testWidgets("shows a very large Markdown file only as its source", (tester) async {
      await _pumpScreen(
        tester,
        reference: const FileReference(absolutePath: "/repo/notes.md", line: null),
        state: FilePreviewShowsText(content: "# Title\n${"word " * 250000}"),
        openExternalLink: _ignoreLink,
      );
      expect(_spanWithText(tester, "# Title"), isNotNull);
      expect(find.byKey(const Key("file-preview-source-toggle")), findsNothing);
    });

    group("HTML", () {
      const page = "<h1>Report</h1>";
      late _FakeWebViewPlatform webViews;
      setUp(() => WebViewPlatform.instance = webViews = _FakeWebViewPlatform());

      testWidgets("renders in a web view and toggles to its source", (tester) async {
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.html", line: null),
          state: const FilePreviewShowsText(content: page),
          openExternalLink: _ignoreLink,
        );
        expect(find.byKey(const Key("fake-web-view")), findsOneWidget);
        final controller = webViews.controllers.single;
        expect(controller.loadedHtml, [page], reason: "without a bottom inset the page needs no room");
        expect(controller.javaScriptMode, JavaScriptMode.unrestricted);

        await tester.tap(find.byKey(const Key("file-preview-source-toggle")));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key("fake-web-view")), findsNothing);
        expect(_spanWithText(tester, "Report"), isNotNull);

        await tester.tap(find.byKey(const Key("file-preview-source-toggle")));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key("fake-web-view")), findsOneWidget);
        expect(webViews.controllers.single, same(controller), reason: "the page is kept, not loaded again");
      });

      testWidgets("fills to the bottom edge, under the home indicator", (tester) async {
        tester.view.padding = FakeViewPadding(bottom: 34 * tester.view.devicePixelRatio);
        addTearDown(tester.view.resetPadding);
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.html", line: null),
          state: const FilePreviewShowsText(content: page),
          openExternalLink: _ignoreLink,
        );
        webViews.controllers.single.finishPage(url: "about:blank");
        await tester.pump();

        final screen = tester.getRect(find.byType(FilePreviewScreen));
        expect(tester.getRect(find.byKey(const Key("fake-web-view"))).bottom, screen.bottom);
      });

      testWidgets("adds room under the home indicator to the page but not its source", (tester) async {
        tester.view.viewPadding = FakeViewPadding(bottom: 34 * tester.view.devicePixelRatio);
        addTearDown(tester.view.resetViewPadding);
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.html", line: null),
          state: const FilePreviewShowsText(content: page),
          openExternalLink: _ignoreLink,
        );
        const roomy = "$page<style>body::after{content:'';display:block;height:34.0px}</style>";
        final controller = webViews.controllers.single;
        expect(controller.loadedHtml, [roomy]);

        controller.startPage(url: "https://example.com/auto-submit");
        expect(controller.loadedHtml, [roomy, roomy], reason: "the file comes back with its room");

        await tester.tap(find.byKey(const Key("file-preview-source-toggle")));
        await tester.pumpAndSettle();
        expect(find.textContaining(page, findRichText: true), findsOneWidget);
        expect(find.textContaining("<style>", findRichText: true), findsNothing);
      });

      testWidgets("opens on its source when the reference names a line", (tester) async {
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.htm", line: 1),
          state: const FilePreviewShowsText(content: page),
          openExternalLink: _ignoreLink,
        );
        expect(find.byKey(const Key("fake-web-view")), findsNothing);
        expect(_spanWithText(tester, "Report"), isNotNull);
        expect(find.byKey(const Key("file-preview-source-toggle")), findsOneWidget);
      });

      testWidgets(
        "shows only its source without a web view",
        (tester) async {
          await _pumpScreen(
            tester,
            reference: const FileReference(absolutePath: "/repo/report.html", line: null),
            state: const FilePreviewShowsText(content: page),
            openExternalLink: _ignoreLink,
          );
          expect(find.byKey(const Key("fake-web-view")), findsNothing);
          expect(find.byKey(const Key("file-preview-source-toggle")), findsNothing);
          expect(_spanWithText(tester, "Report"), isNotNull);
        },
        variant: const TargetPlatformVariant({TargetPlatform.linux, TargetPlatform.windows}),
      );

      testWidgets("covers the web view with a loading indicator until the file loads", (tester) async {
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.html", line: null),
          state: const FilePreviewShowsText(content: page),
          openExternalLink: _ignoreLink,
        );
        expect(find.byKey(const Key("file-preview-html-loading")), findsOneWidget);
        expect(find.byType(PregoActivityIndicator), findsOneWidget);

        webViews.controllers.single.finishPage(url: "about:blank");
        await tester.pump();
        expect(find.byKey(const Key("file-preview-html-loading")), findsNothing);
        expect(find.byKey(const Key("fake-web-view")), findsOneWidget);
      });

      testWidgets("keeps the page and opens nothing a script navigates to", (tester) async {
        final opened = <(Uri, UrlLaunchMode)>[];
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.html", line: null),
          state: const FilePreviewShowsText(content: page),
          openExternalLink: ({required url, required mode}) async {
            opened.add((url, mode));
            return true;
          },
        );
        final controller = webViews.controllers.single;

        expect(await controller.decide(url: "about:blank", isMainFrame: true), NavigationDecision.navigate);
        expect(await controller.decide(url: "about:blank#results", isMainFrame: true), NavigationDecision.navigate);
        expect(
          await controller.decide(url: "https://cdn.example.com/embed", isMainFrame: false),
          NavigationDecision.navigate,
        );
        expect(await controller.decide(url: "file:///etc/hosts", isMainFrame: true), NavigationDecision.prevent);
        expect(
          await controller.decide(url: "https://user:pw@example.com", isMainFrame: true),
          NavigationDecision.prevent,
        );
        expect(await controller.decide(url: "https://example.com/docs", isMainFrame: true), NavigationDecision.prevent);
        expect(opened, isEmpty, reason: "nothing touched the page, so a script navigated");
      });

      testWidgets("sends a tapped web link to the browser and keeps the page", (tester) async {
        final opened = <(Uri, UrlLaunchMode)>[];
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.html", line: null),
          state: const FilePreviewShowsText(content: page),
          openExternalLink: ({required url, required mode}) async {
            opened.add((url, mode));
            return true;
          },
        );
        final controller = webViews.controllers.single..finishPage(url: "about:blank");
        await tester.pump();

        await tester.tapAt(tester.getCenter(find.byKey(const Key("fake-web-view"))));
        expect(
          await controller.decide(url: "https://user:pw@example.com", isMainFrame: true),
          NavigationDecision.prevent,
        );
        expect(opened, isEmpty);
        expect(await controller.decide(url: "https://example.com/docs", isMainFrame: true), NavigationDecision.prevent);
        expect(opened, [(Uri.parse("https://example.com/docs"), UrlLaunchMode.externalApp)]);
      });

      testWidgets("returns to the file when a page it never asked about starts", (tester) async {
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.html", line: null),
          state: const FilePreviewShowsText(content: page),
          openExternalLink: _ignoreLink,
        );
        final controller = webViews.controllers.single..finishPage(url: "about:blank");
        await tester.pump();

        controller.startPage(url: "about:blank");
        expect(controller.loadedHtml, [page]);

        // Android submits a POST form without asking the navigation delegate.
        await tester.tapAt(tester.getCenter(find.byKey(const Key("fake-web-view"))));
        controller.startPage(url: "https://example.com/submit");
        expect(controller.loadedHtml, [page, page]);
        expect(
          controller.javaScriptMode,
          JavaScriptMode.unrestricted,
          reason: "a tapped form keeps the page's scripts",
        );
      });

      testWidgets("returns to the file without scripts when a script left it", (tester) async {
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.html", line: null),
          state: const FilePreviewShowsText(content: page),
          openExternalLink: _ignoreLink,
        );
        final controller = webViews.controllers.single;

        // A script that submits a form on load would submit again from the
        // reloaded file, forever.
        controller.startPage(url: "https://example.com/auto-submit");
        expect(controller.loadedHtml, [page, page]);
        expect(controller.javaScriptMode, JavaScriptMode.disabled);
      });
    });

    testWidgets("hands an image to the image viewer", (tester) async {
      await _pumpScreen(
        tester,
        reference: const FileReference(absolutePath: "/repo/shot.png", line: null),
        state: FilePreviewShowsImage(bytes: _png, mime: "image/png"),
        openExternalLink: _ignoreLink,
      );
      expect(find.byType(ImageAttachmentViewer), findsOneWidget);
    });

    group("a PDF", () {
      // pdfrx otherwise asks path_provider, which tests lack, for its cache.
      setUp(() => Pdfrx.cacheDirectoryPath = Directory.systemTemp.path);
      setUpAll(() => registerFallbackValue(Offset.zero));

      testWidgets("shows its pages in the PDF viewer", (tester) async {
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.pdf", line: null),
          state: FilePreviewShowsPdf(bytes: Uint8List.fromList(utf8.encode("%PDF-1.4"))),
          openExternalLink: _ignoreLink,
        );
        expect(find.byType(PdfViewer), findsOneWidget);
      });

      testWidgets("opens each load's bytes, not another open preview of the same path", (tester) async {
        Future<PdfDocumentRefKey> keyFor(Uint8List bytes) async {
          await _pumpScreen(
            tester,
            reference: const FileReference(absolutePath: "/repo/report.pdf", line: null),
            state: FilePreviewShowsPdf(bytes: bytes),
            openExternalLink: _ignoreLink,
          );
          return tester.widget<PdfViewer>(find.byType(PdfViewer)).documentRef.key;
        }

        final first = Uint8List.fromList(utf8.encode("%PDF-1.4 first"));
        // pdfrx shares one open document per key, so an edited file read again
        // while an earlier preview of it is still open, closing, must not get
        // the earlier document.
        expect(await keyFor(first), isNot(await keyFor(Uint8List.fromList(utf8.encode("%PDF-1.4 edited")))));
        expect(await keyFor(first), await keyFor(first));
      });

      testWidgets("zooms in where a double tap lands, and leaves other taps alone", (tester) async {
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.pdf", line: null),
          state: FilePreviewShowsPdf(bytes: Uint8List.fromList(utf8.encode("%PDF-1.4"))),
          openExternalLink: _ignoreLink,
        );
        final onGeneralTap = tester.widget<PdfViewer>(find.byType(PdfViewer)).params.onGeneralTap;
        expect(onGeneralTap, isNotNull);
        if (onGeneralTap == null) return;
        final controller = _MockPdfViewerController();
        when(
          () => controller.zoomUpOnLocalPosition(
            localPosition: any(named: "localPosition"),
            loop: any(named: "loop"),
          ),
        ).thenAnswer((_) async {});
        PdfViewerGeneralTapHandlerDetails tap(PdfViewerGeneralTapType type) => PdfViewerGeneralTapHandlerDetails(
          localPosition: const Offset(120, 240),
          documentPosition: Offset.zero,
          type: type,
          tapOn: PdfViewerPart.background,
        );
        final context = tester.element(find.byType(PdfViewer));

        expect(onGeneralTap(context, controller, tap(PdfViewerGeneralTapType.tap)), isFalse);
        verifyNever(
          () => controller.zoomUpOnLocalPosition(
            localPosition: any(named: "localPosition"),
            loop: any(named: "loop"),
          ),
        );
        expect(onGeneralTap(context, controller, tap(PdfViewerGeneralTapType.doubleTap)), isTrue);
        verify(() => controller.zoomUpOnLocalPosition(localPosition: const Offset(120, 240), loop: true)).called(1);
      });

      testWidgets("lets the last page scroll clear of the home indicator", (tester) async {
        tester.view.padding = const FakeViewPadding(bottom: 102);
        addTearDown(tester.view.resetPadding);
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/report.pdf", line: null),
          state: FilePreviewShowsPdf(bytes: Uint8List.fromList(utf8.encode("%PDF-1.4"))),
          openExternalLink: _ignoreLink,
        );
        final bottomInset = MediaQuery.paddingOf(tester.element(find.byType(PdfViewer))).bottom;
        expect(bottomInset, greaterThan(0));
        expect(
          tester.widget<PdfViewer>(find.byType(PdfViewer)).params.boundaryMargin,
          EdgeInsets.only(bottom: bottomInset),
        );
      });
    });

    group("on a narrow screen", () {
      const longName = "image_picker_A3883905-28EE-472D-BAFC-82C4A6F3D1E2-00000058381D0921.jpg";

      void useNarrowScreen(WidgetTester tester) {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }

      /// [name] as drawn inside [within].
      RenderEllipsisText shownName(WidgetTester tester, {required String name, required Finder within}) =>
          tester.renderObject<RenderEllipsisText>(find.descendant(of: within, matching: find.text(name)));

      testWidgets("cuts the middle of a long name so its extension shows", (tester) async {
        useNarrowScreen(tester);
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/tmp/$longName", line: null),
          state: const FilePreviewShowsText(content: "alpha"),
          openExternalLink: _ignoreLink,
        );
        final name = shownName(tester, name: longName, within: find.byType(FilePreviewScreen));
        expect(name.shownText, startsWith("image_pic"));
        expect(name.shownText, contains(PregoEllipsis.glyph));
        expect(name.shownText, endsWith(".jpg"));
        expect(name.localToGlobal(Offset(name.size.width, 0)).dx, lessThanOrEqualTo(360));
        expect(find.bySemanticsLabel(RegExp(RegExp.escape(longName))), findsOneWidget);
      });

      testWidgets("cuts the middle of a long path so its file name shows", (tester) async {
        useNarrowScreen(tester);
        const path = "/Users/someone/projects/sesori_apps_monorepo/client/tmp/$longName";
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: path, line: null),
          state: const FilePreviewShowsText(content: "alpha"),
          openExternalLink: _ignoreLink,
        );
        final shownPath = shownName(tester, name: path, within: find.byType(FilePreviewScreen));
        expect(shownPath.shownText, startsWith("/Users/"));
        expect(shownPath.shownText, contains(PregoEllipsis.glyph));
        expect(shownPath.shownText, endsWith(".jpg"));
        expect(shownPath.localToGlobal(Offset(shownPath.size.width, 0)).dx, lessThanOrEqualTo(360));
        expect(find.bySemanticsLabel(RegExp(RegExp.escape(path))), findsOneWidget);
      });

      testWidgets("shows a short name whole", (tester) async {
        useNarrowScreen(tester);
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/lib/main.dart", line: null),
          state: const FilePreviewShowsText(content: "alpha"),
          openExternalLink: _ignoreLink,
        );
        expect(shownName(tester, name: "main.dart", within: find.byType(FilePreviewScreen)).shownText, "main.dart");
      });

      testWidgets("cuts the middle of a long image name in the image viewer", (tester) async {
        useNarrowScreen(tester);
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/tmp/$longName", line: null),
          state: FilePreviewShowsImage(bytes: _png, mime: "image/jpeg"),
          openExternalLink: _ignoreLink,
        );
        final name = shownName(tester, name: longName, within: find.byType(ImageAttachmentViewer));
        expect(name.shownText, contains(PregoEllipsis.glyph));
        expect(name.shownText, endsWith(".jpg"));
      });
    });

    final messages = <FilePreviewUnavailableReason, String>{
      FilePreviewUnavailableReason.missing: "File not found",
      FilePreviewUnavailableReason.tooLarge: "File too large to preview",
      FilePreviewUnavailableReason.unsupported: "This file can’t be previewed",
      FilePreviewUnavailableReason.denied: "The bridge isn’t allowed to read this file",
      FilePreviewUnavailableReason.bridgeTooOld: "Update the bridge to preview files",
      FilePreviewUnavailableReason.failed: "Couldn’t load this file",
    };
    for (final MapEntry(key: reason, value: message) in messages.entries) {
      testWidgets("explains ${reason.name}", (tester) async {
        await _pumpScreen(
          tester,
          reference: const FileReference(absolutePath: "/repo/a.bin", line: null),
          state: FilePreviewUnavailable(reason: reason),
          openExternalLink: _ignoreLink,
        );
        expect(find.text(message), findsOneWidget);
      });
    }
  });

  test("splitSpanIntoLines keeps each piece's style", () {
    const bold = TextStyle(fontWeight: FontWeight.bold);
    final lines = splitSpanIntoLines(
      span: const TextSpan(
        style: TextStyle(fontSize: 10),
        children: [
          TextSpan(text: "a\nb", style: bold),
          TextSpan(text: "c\n"),
        ],
      ),
    );
    expect(lines.map((line) => line.toPlainText()), ["a", "bc", ""]);
    expect(lines.first.children?.single.style, const TextStyle(fontSize: 10).merge(bold));
  });
}
