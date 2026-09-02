import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

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

void main() {
  testWidgets("unsupported voice forces a text-first composer without a VoiceInputCubit", (tester) async {
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
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
          // Even an inconsistent persisted preference must not expose a dead
          // voice entry when the product has no capture implementation.
          inputMode: ChatInputMode.voiceFirst,
          isKeyboardVisible: false,
          attachmentDispatcher: () => attachmentDispatcher,
          imageClipboard: () => imageClipboard,
          child: Scaffold(
            body: PromptInput(
              isBusy: false,
              hasMessages: false,
              onSend: ({required draft, required command, required attachments}) {},
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
              attachmentsSupported: true,
              draftIdentity: "desktop-session",
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

    expect(find.text("Ask anything..."), findsOneWidget);
    expect(find.byIcon(TablerRegular.microphone), findsNothing);

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    expect(find.byIcon(TablerRegular.photo), findsOneWidget);
  });
}
