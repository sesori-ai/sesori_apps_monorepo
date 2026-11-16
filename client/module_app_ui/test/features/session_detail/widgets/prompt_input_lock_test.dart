import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/composer_attachment_dispatcher_fixture.dart";

const _note = "Sending your edit. You can type again in a moment.";

class _NoOpImageClipboard() implements ImageClipboard {
  @override
  Future<Uint8List?> readImage() async => null;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {}
}

Finder _tooltip(String message) => find.byWidgetPredicate((widget) => widget is Tooltip && widget.message == message);

double _opacity(WidgetTester tester) => tester
    .widgetList<AnimatedOpacity>(
      find.ancestor(of: find.byType(TextField), matching: find.byType(AnimatedOpacity)),
    )
    .map((widget) => widget.opacity)
    .reduce((a, b) => a * b);

void main() {
  final image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List(16), filename: "Photo.png");

  testWidgets("a locked composer dims, keeps its words and answers a tap with its note", (tester) async {
    await _pumpComposer(tester: tester, initialAttachments: const [], onAttachmentsChanged: null, lockedNote: _note);

    expect(_opacity(tester), closeTo(0.6, 0.001));
    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(find.text(_note), findsOneWidget);
    expect(find.text("the edit"), findsOneWidget);
    await tester.pumpAndSettle(PregoPopupAlertPresenter.defaultDuration);
  });

  testWidgets("typing into a focused composer that locks changes nothing and shows the note", (tester) async {
    await _pumpComposer(tester: tester, initialAttachments: const [], onAttachmentsChanged: null, lockedNote: null);
    await tester.showKeyboard(find.byType(TextField));
    await _pumpComposer(tester: tester, initialAttachments: const [], onAttachmentsChanged: null, lockedNote: _note);

    tester.testTextInput.updateEditingValue(const TextEditingValue(text: "the edit, more"));
    await tester.pump();

    expect(find.text("the edit"), findsOneWidget);
    expect(find.text(_note), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
      reason: "the keyboard stays up, so nothing moves",
    );
    await tester.pumpAndSettle(PregoPopupAlertPresenter.defaultDuration);
  });

  testWidgets("Enter in a focused composer that locks shows the note instead of sending", (tester) async {
    await _pumpComposer(tester: tester, initialAttachments: const [], onAttachmentsChanged: null, lockedNote: null);
    await tester.showKeyboard(find.byType(TextField));
    await _pumpComposer(tester: tester, initialAttachments: const [], onAttachmentsChanged: null, lockedNote: _note);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.text(_note), findsOneWidget);
    expect(find.text("the edit"), findsOneWidget);
    await tester.pumpAndSettle(PregoPopupAlertPresenter.defaultDuration);
  });

  testWidgets("a locked composer keeps its attachments", (tester) async {
    final reported = <List<ComposerAttachment>>[];
    await _pumpComposer(
      tester: tester,
      initialAttachments: [image],
      onAttachmentsChanged: reported.add,
      lockedNote: _note,
    );

    final reportsBefore = reported.length;

    await tester.tap(_tooltip("Remove attachment"), warnIfMissed: false);
    await tester.pump();

    expect(find.byType(PregoImageAttachmentPreview), findsOneWidget);
    expect(reported, hasLength(reportsBefore));
    expect(find.text(_note), findsOneWidget);
    await tester.pumpAndSettle(PregoPopupAlertPresenter.defaultDuration);
  });

  testWidgets("unlocking brings the composer back at full strength", (tester) async {
    await _pumpComposer(tester: tester, initialAttachments: const [], onAttachmentsChanged: null, lockedNote: _note);
    await _pumpComposer(tester: tester, initialAttachments: const [], onAttachmentsChanged: null, lockedNote: null);

    expect(_opacity(tester), 1);
    await tester.enterText(find.byType(TextField), "the edit, more");
    expect(find.text("the edit, more"), findsOneWidget);
    expect(find.text(_note), findsNothing);
  });
}

Future<void> _pumpComposer({
  required WidgetTester tester,
  required List<ComposerAttachment> initialAttachments,
  required ValueChanged<List<ComposerAttachment>>? onAttachmentsChanged,
  required String? lockedNote,
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
              lockedNote: lockedNote,
              submitAction: null,
              onSend: ({required draft, required command, required attachments}) {},
              onVoiceTranscriptionFinished: null,
              onDraftChanged: (_) {},
              onDraftCleared: () {},
              onAbort: () {},
              surfaceStyleController: surfaceStyle,
              sideQuestion: null,
              composerHeader: null,
              composerTrailing: null,
              availableCommands: const [],
              stagedCommand: null,
              onCommandSelected: (_) {},
              onCommandCleared: () {},
              attachmentsSupported: true,
              fileUploadsSupported: false,
              draftIdentity: "lock-session",
              restorationKey: null,
              initialDraft: ComposerDraft.typed(text: "the edit"),
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
