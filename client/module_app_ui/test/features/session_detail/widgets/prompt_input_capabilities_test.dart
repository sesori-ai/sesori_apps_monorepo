import "dart:typed_data";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
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

class _MockVoiceInputCubit() extends MockCubit<VoiceInputState> implements VoiceInputCubit;

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
          sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
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

  testWidgets("defers surface-style synchronization while dependencies rebuild", (tester) async {
    final inputMode = ValueNotifier(ChatInputMode.textFirst);
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.emphasized);
    final attachmentDispatcher = ComposerAttachmentDispatcher(imagePicker: _NoOpComposerImagePicker());
    final imageClipboard = _NoOpImageClipboard();
    final voiceCubit = _MockVoiceInputCubit();
    whenListen(
      voiceCubit,
      const Stream<VoiceInputState>.empty(),
      initialState: const VoiceInputState.idle(),
    );
    addTearDown(inputMode.dispose);
    addTearDown(surfaceStyle.dispose);
    addTearDown(voiceCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<VoiceInputCubit>.value(
          value: voiceCubit,
          child: ValueListenableBuilder<ChatInputMode>(
            valueListenable: inputMode,
            builder: (context, mode, _) => ComposerPresentationScope(
              voiceSupport: ComposerVoiceSupport.supported,
              inputMode: mode,
              isKeyboardVisible: false,
              sendKeyPolicy: ComposerSendKeyPolicy.modifierEnterSends,
              attachmentDispatcher: () => attachmentDispatcher,
              imageClipboard: () => imageClipboard,
              child: Scaffold(
                body: Column(
                  children: [
                    ValueListenableBuilder<PregoComposerSurfaceStyle>(
                      valueListenable: surfaceStyle,
                      builder: (context, style, _) => Text(style.name),
                    ),
                    PromptInput(
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
                      draftIdentity: "mobile-session",
                      restorationKey: null,
                      initialDraft: ComposerDraft.typed(text: ""),
                      initialAttachments: const [],
                      onInitialAttachmentsConsumed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    inputMode.value = ChatInputMode.voiceFirst;
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(surfaceStyle.value, PregoComposerSurfaceStyle.subtle);
  });
}
