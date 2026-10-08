import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

class _MockVoiceInputCubit() extends MockCubit<VoiceInputState> implements VoiceInputCubit;

void main() {
  late StreamController<VoiceInputState> voiceStates;
  late _MockVoiceInputCubit voiceCubit;

  setUp(() {
    voiceStates = StreamController<VoiceInputState>();
    voiceCubit = _MockVoiceInputCubit();
    whenListen(voiceCubit, voiceStates.stream, initialState: const VoiceInputState.idle());
    when(() => voiceCubit.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(voiceCubit.startRecording).thenAnswer((_) async {
      voiceStates.add(const VoiceInputState.recording());
      await Future<void>.delayed(Duration.zero);
    });
    when(() => voiceCubit.stopAndTranscribe(limitReached: false)).thenAnswer((_) async {});
    when(voiceCubit.cancel).thenAnswer((_) async {});
    addTearDown(voiceStates.close);
    addTearDown(voiceCubit.close);
  });

  testWidgets("a pointer mic click starts listening and a second click transcribes", (tester) async {
    await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit);

    await tester.tap(find.byTooltip("Record voice"));
    await tester.pump();
    verify(voiceCubit.startRecording).called(1);
    expect(find.text("Click the mic to transcribe · Esc to cancel"), findsOneWidget);
    // Clicks are not holds: releasing the first click keeps the mic listening.
    verifyNever(() => voiceCubit.stopAndTranscribe(limitReached: false));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip("Stop and transcribe"));
    await tester.pump();
    verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);
    verifyNever(voiceCubit.cancel);
  });

  testWidgets("Escape cancels a click-started recording", (tester) async {
    await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit);

    await tester.tap(find.byTooltip("Record voice"));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    verify(voiceCubit.cancel).called(1);
    verifyNever(() => voiceCubit.stopAndTranscribe(limitReached: false));
  });
}

Future<void> _pumpPointerComposer({required WidgetTester tester, required VoiceInputCubit voiceCubit}) async {
  final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.emphasized);
  addTearDown(surfaceStyle.dispose);
  final attachmentDispatcher = ComposerAttachmentDispatcher(imagePicker: _NoOpComposerImagePicker());
  final imageClipboard = _NoOpImageClipboard();

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<VoiceInputCubit>.value(
        value: voiceCubit,
        child: ComposerPresentationScope(
          voiceSupport: ComposerVoiceSupport.supported,
          inputMode: ChatInputMode.textFirst,
          isKeyboardVisible: false,
          sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
          presentation: ComposerPresentation.pointer,
          attachmentDispatcher: () => attachmentDispatcher,
          imageClipboard: () => imageClipboard,
          child: Scaffold(
            body: PromptInput(
              initialSelection: null,
              onBusyChanged: null,
              onSelectionChanged: null,
              isBusy: false,
              hasMessages: true,
              canSend: true,
              onSend: ({required draft, required command, required attachments}) {},
              onVoiceTranscriptionCompleted: null,
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
              attachmentsSupported: false,
              draftIdentity: "pointer-voice-test",
              restorationKey: null,
              initialDraft: ComposerDraft.typed(text: ""),
              initialAttachments: const [],
              onAttachmentsChanged: null,
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
