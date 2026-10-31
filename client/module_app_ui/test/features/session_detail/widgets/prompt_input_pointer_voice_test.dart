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

final _mic = find.byTooltip("Record voice");
final _wideSend = find.byType(PregoVoiceSendButton);
final _pencil = _labelledTooltip("Edit before sending");
final _cancel = _labelledTooltip("Cancel recording");
final _cancelTranscription = _labelledTooltip("Cancel transcription");

/// A tooltip excluded from semantics because its target announces the same
/// words itself, which [CommonFinders.byTooltip] cannot see.
Finder _labelledTooltip(String message) =>
    find.byWidgetPredicate((widget) => widget is Tooltip && widget.message == message);

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
    when(() => voiceCubit.stopAndTranscribe(limitReached: false)).thenAnswer((_) async {
      voiceStates.add(const VoiceInputState.transcribing(limitReached: false));
      await Future<void>.delayed(Duration.zero);
    });
    when(voiceCubit.cancel).thenAnswer((_) async {});
    addTearDown(voiceStates.close);
    addTearDown(voiceCubit.close);
  });

  /// Clicks the mic and waits past the 200 ms minimum and the merge.
  Future<void> startListening(WidgetTester tester) async {
    await tester.tap(_mic);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    verify(voiceCubit.startRecording).called(1);
  }

  /// Delivers the transcription's result, as the cubit does once it settles.
  Future<void> completeTranscription(
    WidgetTester tester, {
    String transcript = "spoken words",
    VoiceDictationOutcome outcome = VoiceDictationOutcome.finished,
  }) async {
    voiceStates.add(
      VoiceInputState.completed(transcript: transcript, outcome: outcome, mode: VoiceDictationMode.afterRecording),
    );
    await tester.pump();
    await tester.pump();
    voiceStates.add(const VoiceInputState.idle());
    await tester.pump(const Duration(milliseconds: 500));
  }

  group("finishing", () {
    testWidgets("click, speak, click sends through the composer and reports sent", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness);

      await startListening(tester);
      expect(find.text("Enter to send"), findsOneWidget);
      // Clicks are not holds: releasing the first click keeps the mic listening.
      verifyNever(() => voiceCubit.stopAndTranscribe(limitReached: false));

      await tester.tap(_wideSend);
      await tester.pump();
      verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);
      verifyNever(voiceCubit.cancel);
      expect(harness.sent, isEmpty, reason: "Nothing leaves until the words arrive.");

      await completeTranscription(tester);

      expect(harness.sent, ["spoken words"]);
      expect(harness.finishes, [AnalyticsVoiceFinish.sent]);
    });

    testWidgets("Enter sends with focus held by the composer", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness);

      await startListening(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);

      await completeTranscription(tester);

      expect(harness.sent, ["spoken words"]);
      expect(harness.finishes, [AnalyticsVoiceFinish.sent]);
    });

    testWidgets("Enter with the field focused inserts no newline and sends one combined message", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, initialText: "typed first");
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final fieldFocus = FocusManager.instance.primaryFocus;
      expect(fieldFocus?.context?.findAncestorWidgetOfExactType<TextField>(), isNotNull);

      await startListening(tester);
      expect(FocusManager.instance.primaryFocus, fieldFocus, reason: "The mic click keeps the field's focus.");

      // A key the framework handles never reaches the platform text input,
      // which is what would have inserted the newline.
      final handled = await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(handled, isTrue);
      expect(_fieldText(tester), "typed first");
      expect(harness.sent, isEmpty, reason: "The box must not go out ahead of the words.");
      verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);
      expect(FocusManager.instance.primaryFocus, fieldFocus);

      await completeTranscription(tester);

      expect(harness.sent, ["typed first spoken words"]);
      expect(harness.finishes, [AnalyticsVoiceFinish.sent]);
    });

    testWidgets("the keyboard starts from the mic, loses the hidden buttons, and still finishes", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, initialText: "typed first");
      final micFocus = Focus.of(tester.element(find.byIcon(TablerRegular.microphone)));
      // The row's send comes before the wide Send, which shares its arrow.
      final sendFocus = Focus.of(tester.element(find.byIcon(TablerRegular.arrow_up).first));
      micFocus.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      verify(voiceCubit.startRecording).called(1);

      expect(micFocus.hasFocus, isFalse);
      expect(micFocus.canRequestFocus, isFalse);
      expect(sendFocus.canRequestFocus, isFalse);

      expect(await tester.sendKeyDownEvent(LogicalKeyboardKey.enter), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);

      await completeTranscription(tester);
      expect(harness.sent, ["typed first spoken words"]);
      expect(Focus.of(tester.element(find.byIcon(TablerRegular.microphone))).canRequestFocus, isTrue);
    });

    testWidgets("Enter while the words are on their way is handled with focus held by the composer", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness);

      await startListening(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final handled = await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(handled, isTrue);
      expect(harness.sent, isEmpty);
    });

    testWidgets("Enter while the words are on their way sends nothing extra", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, initialText: "typed first");
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await startListening(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final handled = await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(handled, isTrue);
      expect(harness.sent, isEmpty);
      verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);

      await completeTranscription(tester);
      expect(harness.sent, ["typed first spoken words"]);
    });

    testWidgets("Shift+Enter puts the words in the box without a newline", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, initialText: "typed first");
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await startListening(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      final handled = await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(handled, isTrue);
      expect(_fieldText(tester), "typed first");
      verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);

      await completeTranscription(tester);

      expect(harness.sent, isEmpty);
      expect(harness.finishes, [AnalyticsVoiceFinish.edited]);
      expect(_fieldText(tester), "typed first spoken words");
    });

    testWidgets("the pencil puts the words in the box", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness);

      await startListening(tester);
      await tester.tap(_pencil);
      await tester.pump();
      verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);

      await completeTranscription(tester);

      expect(harness.sent, isEmpty);
      expect(harness.finishes, [AnalyticsVoiceFinish.edited]);
      expect(_fieldText(tester), "spoken words");
    });

    testWidgets("a refused send leaves the words in the box", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, canSend: false);

      await startListening(tester);
      await tester.tap(_wideSend);
      await tester.pump();
      await completeTranscription(tester);

      expect(harness.sent, isEmpty);
      expect(harness.finishes, [AnalyticsVoiceFinish.edited]);
      expect(_fieldText(tester), "spoken words");
    });

    testWidgets("a dictation cut off at the limit lands in the box with the notice", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness);

      await startListening(tester);
      voiceStates.add(const VoiceInputState.transcribing(limitReached: true));
      await tester.pump();
      await tester.pump();
      expect(find.text("Recording limit reached (15 minutes)"), findsOneWidget);
      expect(tester.widget<PregoVoiceSendButton>(_wideSend).enabled, isFalse);

      await completeTranscription(tester, outcome: VoiceDictationOutcome.limitReached);

      expect(harness.sent, isEmpty);
      expect(harness.finishes, [AnalyticsVoiceFinish.cutOff]);
      expect(_fieldText(tester), "spoken words");
    });

    testWidgets("an empty transcript sends nothing and keeps the box", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, initialText: "typed first");

      await startListening(tester);
      await tester.tap(_wideSend);
      await tester.pump();
      await completeTranscription(tester, transcript: "  ");

      expect(harness.sent, isEmpty);
      expect(harness.finishes, isEmpty);
      expect(_fieldText(tester), "typed first");
    });

    testWidgets("a second click under 200 ms discards instead of transcribing", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness);

      await tester.tap(_mic);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(_wideSend, warnIfMissed: false);
      await tester.pump();

      verify(voiceCubit.cancel).called(1);
      verifyNever(() => voiceCubit.stopAndTranscribe(limitReached: false));
      expect(harness.sent, isEmpty);
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group("cancelling", () {
    testWidgets("Escape cancels and keeps the box", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, initialText: "typed first");

      await startListening(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      verify(voiceCubit.cancel).called(1);
      verifyNever(() => voiceCubit.stopAndTranscribe(limitReached: false));
      expect(harness.sent, isEmpty);
      expect(_fieldText(tester), "typed first");
    });

    testWidgets("Escape cancels with the field focused", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, initialText: "typed first");
      await tester.tap(find.byType(TextField));
      await tester.pump();

      await startListening(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      verify(voiceCubit.cancel).called(1);
      expect(_fieldText(tester), "typed first");
    });

    testWidgets("the X cancels and keeps the box", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, initialText: "typed first");
      expect(find.byType(PregoVoiceTarget), findsNothing);

      await startListening(tester);
      expect(find.byType(PregoVoiceTarget), findsNWidgets(2));

      await tester.tap(_cancel);
      await tester.pump();

      verify(voiceCubit.cancel).called(1);
      verifyNever(() => voiceCubit.stopAndTranscribe(limitReached: false));
      expect(harness.sent, isEmpty);
      expect(_fieldText(tester), "typed first");
    });

    testWidgets("the X stops a transcription from where it was, and nothing else responds", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, initialText: "typed first");

      await startListening(tester);
      final cancelRect = tester.getRect(_cancel);
      final pencilCenter = tester.getCenter(_pencil);
      final sendCenter = tester.getCenter(_wideSend);

      await tester.tap(_wideSend);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);

      expect(tester.getRect(_cancelTranscription), cancelRect);

      // Second clicks on the pencil's place and on the dimmed Send do nothing.
      await tester.tapAt(pencilCenter);
      await tester.tapAt(sendCenter);
      await tester.pump();
      verifyNever(() => voiceCubit.stopAndTranscribe(limitReached: false));
      verifyNever(voiceCubit.cancel);

      await tester.tap(_cancelTranscription);
      await tester.pump();
      verify(voiceCubit.cancel).called(1);

      // A late result from the stopped transcription lands nowhere.
      await completeTranscription(tester);
      expect(harness.sent, isEmpty);
      expect(_fieldText(tester), "typed first");
    });

    testWidgets("Escape stops a transcription too", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness);

      await startListening(tester);
      await tester.tap(_wideSend);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      verify(voiceCubit.cancel).called(1);
    });
  });

  group("feel", () {
    testWidgets("the mic's place lies inside the wide Send, which keeps its place through transcribing", (
      tester,
    ) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness);
      final micRect = tester.getRect(_mic);
      expect(micRect.width, 44);

      await startListening(tester);

      final sendRect = tester.getRect(_wideSend);
      expect(sendRect.width, 94);
      expect(sendRect.height, 44);
      expect(sendRect.expandToInclude(micRect), sendRect);

      // The very spot that was clicked now finishes the dictation.
      await tester.tapAt(micRect.center);
      await tester.pump();
      verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(_wideSend), sendRect);
      expect(tester.widget<PregoVoiceSendButton>(_wideSend).enabled, isFalse);
    });

    testWidgets("the composer and the send's far edge hold still on every frame of the merge and back", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness);
      final composerRect = tester.getRect(find.byType(PromptInput));
      final micRect = tester.getRect(_mic);

      await tester.tap(_mic);
      await tester.pump();
      await tester.pump();
      for (var frame = 0; frame < 16; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(find.byType(PromptInput)), composerRect);
        expect(tester.getRect(_mic), micRect);
        expect(tester.getRect(_wideSend).right, micRect.right + 6 + 44);
      }

      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(_wideSend);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(find.byType(PromptInput)), composerRect);

      voiceStates.add(const VoiceInputState.idle());
      await tester.pump();
      await tester.pump();
      for (var frame = 0; frame < 16; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(_mic), micRect);
        expect(tester.getRect(_wideSend).right, micRect.right + 6 + 44);
      }
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets("the pencil never slides as the options give way to it, nor the options on their way back", (
      tester,
    ) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness);
      final optionsLeft = tester.getRect(find.byType(ComposerOptionsAccordion)).left;

      await tester.tap(_mic);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final pencilRect = tester.getRect(_pencil);
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(_pencil), pencilRect);
      }

      voiceStates.add(const VoiceInputState.idle());
      await tester.pump();
      await tester.pump();
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(find.byType(ComposerOptionsAccordion)).left, optionsLeft);
      }
    });

    testWidgets("reduced motion merges at once", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, reducedMotion: true);
      final micRect = tester.getRect(_mic);

      await tester.tap(_mic);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(tester.getRect(_wideSend).width, 94);
      expect(tester.getRect(_wideSend).left, micRect.left);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets("rest shows no wide Send to hit, only the mic and send", (tester) async {
      final harness = _Harness();
      await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, initialText: "typed first");

      await tester.tap(find.byTooltip("Send").first);
      await tester.pump();

      expect(harness.sent, ["typed first"]);
      verifyNever(voiceCubit.startRecording);
    });
  });

  testWidgets("a retried recording leaves the box free to send", (tester) async {
    final harness = _Harness();
    await _pumpPointerComposer(tester: tester, voiceCubit: voiceCubit, harness: harness, initialText: "typed first");
    when(voiceCubit.retry).thenAnswer((_) async {});
    when(voiceCubit.discard).thenAnswer((_) async {});

    final error = VoiceTranscriptionError.networkError(innerError: null);
    voiceStates.add(VoiceInputState.retryPending(error: error));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key("voice_saved_retry")));
    voiceStates.add(VoiceInputState.retrying(previousError: error));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    expect(harness.sent, ["typed first"]);
    verify(voiceCubit.discard).called(1);
    await tester.pump(const Duration(milliseconds: 300));
  });
}

/// The text the composer's field holds, once the layout that shows it is up.
String _fieldText(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller?.text ?? "";

final class _Harness() {
  final List<String> sent = [];
  final List<AnalyticsVoiceFinish> finishes = [];
}

Future<void> _pumpPointerComposer({
  required WidgetTester tester,
  required VoiceInputCubit voiceCubit,
  required _Harness harness,
  String initialText = "",
  bool canSend = true,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = const Size(760, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.emphasized);
  addTearDown(surfaceStyle.dispose);
  final attachmentDispatcher = ComposerAttachmentDispatcher(imagePicker: _NoOpComposerImagePicker());
  final imageClipboard = _NoOpImageClipboard();

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: const Size(760, 600), disableAnimations: reducedMotion),
        child: BlocProvider<VoiceInputCubit>.value(
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
                canSend: canSend,
                onSend: ({required draft, required command, required attachments}) => harness.sent.add(draft.text),
                onVoiceTranscriptionFinished: ({required finish, required mode}) => harness.finishes.add(finish),
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
                initialDraft: ComposerDraft.typed(text: initialText),
                initialAttachments: const [],
                onAttachmentsChanged: null,
                autofocus: false,
                onInitialAttachmentsConsumed: () {},
              ),
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
