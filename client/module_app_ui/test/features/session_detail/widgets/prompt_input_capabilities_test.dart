import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
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
  testWidgets("staged previews scroll, remove the selected image, and send original remaining bytes", (tester) async {
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
    addTearDown(surfaceStyle.dispose);
    final dispatcher = ComposerAttachmentDispatcher(imagePicker: _NoOpComposerImagePicker());
    final clipboard = _NoOpImageClipboard();
    final images = [
      for (var i = 0; i < 8; i++)
        ComposerAttachment(
          mime: "image/png",
          bytes: base64Decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAAAAAA6fptVAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==",
          ),
          filename: "Photo $i.png",
        ),
    ];
    List<ComposerAttachment>? sent;
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
          attachmentDispatcher: () => dispatcher,
          imageClipboard: () => clipboard,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: PromptInput(
                  isBusy: false,
                  hasMessages: false,
                  onSend: ({required draft, required command, required attachments}) => sent = attachments,
                  onVoiceTranscriptionCompleted: null,
                  onDraftChanged: (_) {},
                  onDraftCleared: () {},
                  onAbort: () {},
                  surfaceStyleController: surfaceStyle,
                  queuedMessages: null,
                  composerHeader: null,
                  availableCommands: const [],
                  stagedCommand: null,
                  onCommandSelected: (_) {},
                  onCommandCleared: () {},
                  attachmentsSupported: true,
                  draftIdentity: "preview-session",
                  restorationKey: null,
                  initialDraft: ComposerDraft.typed(text: ""),
                  initialAttachments: images,
                  onInitialAttachmentsConsumed: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final strip = find.byType(PregoImageAttachmentStrip);
    expect(tester.getSize(strip).height, 52);
    expect(find.byType(PregoImageAttachmentPreview), findsNWidgets(8));
    final firstImage = tester.widget<Image>(find.descendant(of: strip, matching: find.byType(Image)).first);
    expect(firstImage.fit, BoxFit.cover);
    expect((firstImage.image as ResizeImage).width, 156);
    await tester.drag(strip, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(ObjectKey(images.last)), matching: find.byIcon(TablerRegular.x)));
    await tester.pumpAndSettle();
    expect(find.byKey(ObjectKey(images.last)), findsNothing);
    expect(find.byType(PregoImageAttachmentPreview), findsNWidgets(7));
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pumpAndSettle();
    expect(sent, orderedEquals(images.take(7)));
    for (var i = 0; i < sent!.length; i++) {
      expect(identical(sent![i].bytes, images[i].bytes), isTrue);
    }
    expect(strip, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("only the staged chip materializes; clear, voice, and retry preserve the draft", (tester) async {
    final command = ValueNotifier<CommandInfo?>(null);
    final voiceStates = StreamController<VoiceInputState>();
    final voiceCubit = _MockVoiceInputCubit();
    whenListen(voiceCubit, voiceStates.stream, initialState: const VoiceInputState.idle());
    when(() => voiceCubit.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    addTearDown(command.dispose);
    addTearDown(voiceStates.close);
    addTearDown(voiceCubit.close);
    await _pumpCommandComposer(tester: tester, command: command, voiceCubit: voiceCubit, disableAnimations: false);
    await tester.pumpAndSettle();
    expect(find.byType(GlassMaterializeTransition), findsNothing);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), "Keep this draft");

    command.value = _stagedCommand;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final transition = tester.widget<GlassMaterializeTransition>(find.byType(GlassMaterializeTransition));
    expect(transition.animation.value, inExclusiveRange(0, 1));
    expect(transition.child.key, const ValueKey("staged-command"));
    expect(
      find.ancestor(of: find.text("Picker header"), matching: find.byType(GlassMaterializeTransition)),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isTrue);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(command.value, isNull);
    expect(find.byType(GlassMaterializeTransition), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(GlassMaterializeTransition), findsNothing);
    expect(find.text("Picker header"), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, "Keep this draft");
    // The chip sits outside the editor tap region: clearing already dismissed
    // focus before the transition change. Staging still focuses the editor.
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus, isFalse);

    command.value = _stagedCommand;
    await tester.pumpAndSettle();
    voiceStates.add(const VoiceInputState.recording());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey("release-hint")), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey("release-hint")),
        matching: find.byType(GlassMaterializeTransition),
      ),
      findsNothing,
    );
    // The recording waveform keeps ticking; advance past the slot transition.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GlassMaterializeTransition), findsNothing);

    voiceStates.add(VoiceInputState.retryPending(error: VoiceTranscriptionError.networkError()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("saved-recording-actions")), findsOneWidget);
    expect(find.byType(GlassMaterializeTransition), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, "Keep this draft");
  }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS}));

  for (final disableAnimations in [true, false]) {
    testWidgets("staged chip respects ${disableAnimations ? 'Remove animations' : 'iOS Reduce Motion'}", (
      tester,
    ) async {
      final command = ValueNotifier<CommandInfo?>(null);
      addTearDown(command.dispose);
      if (!disableAnimations) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      }
      await _pumpCommandComposer(
        tester: tester,
        command: command,
        voiceCubit: null,
        disableAnimations: disableAnimations,
      );
      await tester.pumpAndSettle();
      command.value = _stagedCommand;
      await tester.pump();
      await tester.pump();
      expect(find.byType(GlassChip), findsOneWidget);
      expect(find.byType(GlassMaterializeTransition), findsNothing);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey("staged-command")),
          matching: find.byType(AnimatedSwitcher),
        ),
        findsNothing,
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump();
      expect(find.byType(GlassChip), findsNothing);
      expect(find.text("Picker header"), findsOneWidget);
    });
  }

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
              queuedMessages: null,
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
    expect(find.byTooltip("Attach image"), findsOneWidget);
    expect(find.byTooltip("More actions"), findsNothing);
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
                      queuedMessages: null,
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

const _stagedCommand = CommandInfo(
  name: "review",
  template: null,
  hints: null,
  description: null,
  agent: null,
  model: null,
  provider: null,
  source: CommandSource.command,
  subtask: null,
);

Future<void> _pumpCommandComposer({
  required WidgetTester tester,
  required ValueNotifier<CommandInfo?> command,
  required VoiceInputCubit? voiceCubit,
  required bool disableAnimations,
}) async {
  final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
  addTearDown(surfaceStyle.dispose);
  final attachmentDispatcher = ComposerAttachmentDispatcher(imagePicker: _NoOpComposerImagePicker());
  final imageClipboard = _NoOpImageClipboard();
  final composer = ValueListenableBuilder<CommandInfo?>(
    valueListenable: command,
    builder: (context, staged, _) => ComposerPresentationScope(
      voiceSupport: voiceCubit == null ? ComposerVoiceSupport.unsupported : ComposerVoiceSupport.supported,
      inputMode: ChatInputMode.textFirst,
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
          queuedMessages: null,
          composerHeader: const Text("Picker header"),
          availableCommands: const [_stagedCommand],
          stagedCommand: staged,
          onCommandSelected: (_) {},
          onCommandCleared: () => command.value = null,
          attachmentsSupported: false,
          draftIdentity: "glass-command-test",
          restorationKey: null,
          initialDraft: ComposerDraft.typed(text: "Initial draft"),
          initialAttachments: const [],
          onInitialAttachmentsConsumed: () {},
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: voiceCubit == null ? composer : BlocProvider<VoiceInputCubit>.value(value: voiceCubit, child: composer),
      ),
    ),
  );
}
