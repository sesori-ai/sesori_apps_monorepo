import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("desktop Enter sends while Shift+Enter remains a newline gesture", (tester) async {
    var sendCount = 0;
    String? sentText;
    await _pumpComposer(
      tester: tester,
      sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
      onSend: ({required draft, required command, required attachments}) {
        sendCount++;
        sentText = draft.text;
      },
    );

    final field = find.byType(TextField);
    await tester.enterText(field, "Ship the fix");
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCount, 1);
    expect(sentText, "Ship the fix");

    await tester.enterText(field, "First line");
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(sendCount, 1);
    await tester.enterText(field, "First line\nSecond line");
    expect(tester.widget<TextField>(field).controller?.text, "First line\nSecond line");
  });

  testWidgets("desktop Enter preserves an active IME composition", (tester) async {
    var sendCount = 0;
    await _pumpComposer(
      tester: tester,
      sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
      onSend: ({required draft, required command, required attachments}) => sendCount++,
    );

    final field = find.byType(TextField);
    final controller = tester.widget<TextField>(field).controller!;
    controller.value = const TextEditingValue(
      text: "候補",
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 0, end: 2),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sendCount, 0);

    controller.value = const TextEditingValue(
      text: "Confirmed",
      selection: TextSelection.collapsed(offset: 9),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sendCount, 1);
  });

  testWidgets("mobile plain Enter does not send and modifier Enter still sends", (tester) async {
    var sendCount = 0;
    await _pumpComposer(
      tester: tester,
      sendKeyPolicy: ComposerSendKeyPolicy.modifierEnterSends,
      onSend: ({required draft, required command, required attachments}) => sendCount++,
    );

    final field = find.byType(TextField);
    await tester.enterText(field, "Mobile line");
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sendCount, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(sendCount, 1);
  });
}

Future<void> _pumpComposer({
  required WidgetTester tester,
  required ComposerSendKeyPolicy sendKeyPolicy,
  required PromptSubmitCallback onSend,
}) async {
  final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.emphasized);
  addTearDown(surfaceStyle.dispose);
  final attachmentDispatcher = ComposerAttachmentDispatcher(imagePicker: _NoOpComposerImagePicker());
  final imageClipboard = _NoOpImageClipboard();

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ComposerPresentationScope(
        voiceSupport: ComposerVoiceSupport.unsupported,
        inputMode: ChatInputMode.textFirst,
        isKeyboardVisible: false,
        sendKeyPolicy: sendKeyPolicy,
        attachmentDispatcher: () => attachmentDispatcher,
        imageClipboard: () => imageClipboard,
        child: Scaffold(
          body: PromptInput(
            isBusy: false,
            hasMessages: true,
            onSend: onSend,
            onVoiceTranscriptionCompleted: null,
            onDraftChanged: (_) {},
            onDraftCleared: () {},
            onAbort: () {},
            surfaceStyleController: surfaceStyle,
            composerHeader: null,
            availableCommands: const [],
            stagedCommand: null,
            onCommandSelected: (_) {},
            onCommandCleared: () {},
            attachmentsSupported: false,
            draftIdentity: "keyboard-test",
            restorationKey: null,
            initialDraft: ComposerDraft.typed(text: ""),
            initialAttachments: const [],
            onInitialAttachmentsConsumed: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text("Follow up..."));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(TextField));
}

class _NoOpComposerImagePicker() implements ComposerImagePicker {
  @override
  Future<ComposerPickedImage?> pickImage() async => null;
}

class _NoOpImageClipboard() implements ImageClipboard {
  @override
  Future<Uint8List?> readImage() async => null;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {}
}
