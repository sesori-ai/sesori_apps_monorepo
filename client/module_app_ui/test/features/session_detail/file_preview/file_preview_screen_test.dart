import "dart:convert";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/gestures.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:markdown/markdown.dart" as md;
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/file_preview/file_preview_screen.dart";
import "package:sesori_app_ui/src/features/session_detail/file_preview/file_reference_code_syntax.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

class _MockFilePreviewCubit() extends MockCubit<FilePreviewState> implements FilePreviewCubit;

class _MockFilePreviewRepository() extends Mock implements FilePreviewRepository;

class _MockImageSaver() extends Mock implements ImageSaver;

class _MockImageClipboard() extends Mock implements ImageClipboard;

class _MockImageSharer() extends Mock implements ImageSharer;

/// A 1×1 transparent PNG.
final _png = base64Decode(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
);

Widget _app({required FilePreviewCubitFactory createFilePreviewCubit, required Widget child}) => MaterialApp(
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
    openExternalLink: ({required url, required mode}) async => false,
    openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
    child: Scaffold(body: child),
  ),
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required FileReference reference,
  required FilePreviewState state,
}) async {
  final cubit = _MockFilePreviewCubit();
  whenListen(cubit, const Stream<FilePreviewState>.empty(), initialState: state);
  await tester.pumpWidget(
    _app(
      createFilePreviewCubit: ({required reference}) => cubit,
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
        child: BlocProvider<SessionDetailCubit>.value(
          value: sessionCubit,
          child: const TextPartWidget(text: "Look at `lib/main.dart:2` please"),
        ),
      ),
    );
    final span = _spanWithText(tester, "lib/main.dart:2");
    expect(span?.recognizer, isA<TapGestureRecognizer>());
    (span?.recognizer as TapGestureRecognizer?)?.onTap?.call();
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
      );
      expect(find.text("Title"), findsOneWidget);

      await tester.tap(find.byKey(const Key("file-preview-source-toggle")));
      await tester.pumpAndSettle();
      expect(_spanWithText(tester, "# Title"), isNotNull);
    });

    testWidgets("hands an image to the image viewer", (tester) async {
      await _pumpScreen(
        tester,
        reference: const FileReference(absolutePath: "/repo/shot.png", line: null),
        state: FilePreviewShowsImage(bytes: _png, mime: "image/png"),
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
