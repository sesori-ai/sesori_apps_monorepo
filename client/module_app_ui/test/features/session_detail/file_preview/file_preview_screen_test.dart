import "dart:convert";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:markdown/markdown.dart" as md;
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
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
        expect(controller.loadedHtml, [page]);
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
