import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/composer_attachment_dispatcher_fixture.dart";

class _NoOpImageClipboard() implements ImageClipboard {
  @override
  Future<Uint8List?> readImage() async => null;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {}
}

/// The composer's labelled buttons keep their tooltip's words off the semantics
/// tree, which is what `find.byTooltip` reads.
Finder _tooltip(String message) => find.byWidgetPredicate((widget) => widget is Tooltip && widget.message == message);

bool _fieldHasFocus(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

void main() {
  final images = [
    for (var i = 0; i < 2; i++)
      ComposerImageAttachment(mime: "image/png", bytes: Uint8List(16), filename: "Photo $i.png"),
  ];

  testWidgets("with attachments staged, a tap on the padding around the words focuses the field", (tester) async {
    await _pumpComposer(tester: tester, initialAttachments: images, onAttachmentsChanged: null);
    expect(_fieldHasFocus(tester), isFalse);
    final field = tester.getRect(find.byType(TextField));

    // The gap between the words and the action row, just below the hint.
    await tester.tapAt(Offset(field.center.dx, field.bottom + 4));
    await tester.pump();
    expect(_fieldHasFocus(tester), isTrue);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(_fieldHasFocus(tester), isFalse);

    // The box's own padding beside the words.
    await tester.tapAt(Offset(field.left - 4, field.center.dy));
    await tester.pump();
    expect(_fieldHasFocus(tester), isTrue);
  });

  testWidgets("a tile's remove badge removes the tile without focusing the field", (tester) async {
    final reported = <List<ComposerAttachment>>[];
    await _pumpComposer(tester: tester, initialAttachments: images, onAttachmentsChanged: reported.add);

    await tester.tap(_tooltip("Remove attachment").first);
    await tester.pumpAndSettle();

    expect(find.byType(PregoImageAttachmentPreview), findsOneWidget);
    expect(reported.last, [images.last]);
    expect(_fieldHasFocus(tester), isFalse);
  });

  testWidgets("a tap between the tiles leaves the field unfocused", (tester) async {
    await _pumpComposer(tester: tester, initialAttachments: images, onAttachmentsChanged: null);
    final first = tester.getRect(find.byKey(ObjectKey(images.first)));
    final second = tester.getRect(find.byKey(ObjectKey(images.last)));

    await tester.tapAt(Offset((first.right + second.left) / 2, first.center.dy));
    await tester.pump();

    expect(_fieldHasFocus(tester), isFalse);
  });
}

Future<void> _pumpComposer({
  required WidgetTester tester,
  required List<ComposerAttachment> initialAttachments,
  required ValueChanged<List<ComposerAttachment>>? onAttachmentsChanged,
}) async {
  final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
  addTearDown(surfaceStyle.dispose);
  final dispatcher = composerAttachmentDispatcherForTest(
    filePicker: const NoOpComposerFilePicker(),
    downscaleBuilder: const ComposerImageDownscaleBuilder(),
    bridgeIsLocal: false,
  );
  final clipboard = _NoOpImageClipboard();
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ComposerPresentationScope(
        voiceSupport: ComposerVoiceSupport.unsupported,
        inputMode: ChatInputMode.textFirst,
        isKeyboardVisible: false,
        sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
        presentation: ComposerPresentation.touch,
        attachmentDispatcher: () => dispatcher,
        imageClipboard: () => clipboard,
        fileClipboard: null,
        droppedPaths: null,
        attachKind: ComposerAttachKind.photosAndFiles,
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PromptInput(
              initialSelection: null,
              onBusyChanged: null,
              onSelectionChanged: null,
              isBusy: false,
              hasMessages: false,
              canSend: true,
              onSend: ({required draft, required command, required attachments}) {},
              onVoiceTranscriptionFinished: null,
              onDraftChanged: (_) {},
              onDraftCleared: () {},
              onAbort: () {},
              surfaceStyleController: surfaceStyle,
              composerHeader: null,
              composerTrailing: null,
              availableCommands: const [],
              stagedCommand: null,
              onCommandSelected: (_) {},
              onCommandCleared: () {},
              attachmentsSupported: true,
              fileUploadsSupported: false,
              draftIdentity: "tap-area-session",
              restorationKey: null,
              initialDraft: ComposerDraft.typed(text: ""),
              initialAttachments: initialAttachments,
              onAttachmentsChanged: onAttachmentsChanged,
              autofocus: false,
              onInitialAttachmentsConsumed: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
