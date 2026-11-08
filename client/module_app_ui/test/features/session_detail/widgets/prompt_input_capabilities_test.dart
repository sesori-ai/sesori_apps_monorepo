import "dart:async";
import "dart:convert";
import "dart:io";
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

import "../../../helpers/composer_attachment_dispatcher_fixture.dart";

class _NoOpImageClipboard() implements ImageClipboard {
  @override
  Future<Uint8List?> readImage() async => null;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {}
}

class _PendingComposerFilePicker() implements ComposerFilePicker {
  Completer<ComposerPickResult?> result = Completer();

  @override
  Future<ComposerPickResult?> pick() => result.future;
}

class _FixedImageClipboard({required final Uint8List _bytes}) implements ImageClipboard {
  @override
  Future<Uint8List?> readImage() async => _bytes;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {}
}

class _PendingDownscaleBuilder() implements ComposerImageDownscaleBuilder {
  final result = Completer<ComposerImageDownscaleResult>();

  @override
  Future<ComposerImageDownscaleResult> downscale({
    required Uint8List bytes,
    required SupportedRasterImageFormat format,
  }) => result.future;
}

/// Hands out one image per paste, in order.
class _QueuedImageClipboard({required final List<Uint8List> _images}) implements ImageClipboard {
  @override
  Future<Uint8List?> readImage() async => _images.removeAt(0);

  @override
  Future<void> writeImage({required Uint8List bytes}) async {}
}

/// Lets each downscale settle on its own, in any order.
class _QueuedDownscaleBuilder() implements ComposerImageDownscaleBuilder {
  final results = <Completer<ComposerImageDownscaleResult>>[];

  @override
  Future<ComposerImageDownscaleResult> downscale({
    required Uint8List bytes,
    required SupportedRasterImageFormat format,
  }) {
    final result = Completer<ComposerImageDownscaleResult>();
    results.add(result);
    return result.future;
  }
}

class _MockVoiceInputCubit() extends MockCubit<VoiceInputState> implements VoiceInputCubit;

/// The composer's labelled buttons keep their tooltip's words off the semantics
/// tree, which is what `find.byTooltip` reads.
Finder _tooltip(String message) => find.byWidgetPredicate((widget) => widget is Tooltip && widget.message == message);

void main() {
  testWidgets("starts at the handed-over caret and reports busy while an insert or a word is pending", (tester) async {
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
    addTearDown(surfaceStyle.dispose);
    final picker = _PendingComposerFilePicker();
    final dispatcher = composerAttachmentDispatcherForTest(
      filePicker: picker,
      downscaleBuilder: const ComposerImageDownscaleBuilder(),
      bridgeIsLocal: false,
    );
    final clipboard = _NoOpImageClipboard();
    final busy = <bool>[];
    final selections = <({int base, int extent})>[];
    final busyWhenCleared = <List<bool>>[];
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
          droppedPaths: null,
          attachKind: ComposerAttachKind.images,
          child: Scaffold(
            body: PromptInput(
              initialSelection: (base: 5, extent: 2),
              onBusyChanged: busy.add,
              onSelectionChanged: selections.add,
              isBusy: false,
              hasMessages: false,
              canSend: true,
              onSend: ({required draft, required command, required attachments}) {},
              onVoiceTranscriptionFinished: null,
              onDraftChanged: (_) {},
              onDraftCleared: () => busyWhenCleared.add([...busy]),
              onAbort: () {},
              surfaceStyleController: surfaceStyle,
              composerHeader: null,
              composerTrailing: null,
              availableCommands: const [],
              stagedCommand: null,
              onCommandSelected: (_) {},
              onCommandCleared: () {},
              attachmentsSupported: true,
              draftIdentity: "handoff-session",
              restorationKey: null,
              initialDraft: ComposerDraft.typed(text: "carry on"),
              initialAttachments: const [],
              onAttachmentsChanged: null,
              autofocus: false,
              onInitialAttachmentsConsumed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    // A backward selection keeps its active end.
    expect(field.controller?.selection, const TextSelection(baseOffset: 5, extentOffset: 2));

    field.controller?.selection = const TextSelection(baseOffset: 4, extentOffset: 1);
    expect(selections, [(base: 4, extent: 1)]);

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(_tooltip("Attach image"));
    await tester.pump();
    expect(busy, [true]);
    picker.result.complete(null);
    await tester.pumpAndSettle();
    expect(busy, [true, false]);

    field.controller?.value = const TextEditingValue(
      text: "carry onw",
      selection: TextSelection.collapsed(offset: 9),
      composing: TextRange(start: 6, end: 9),
    );
    expect(busy, [true, false, true]);
    field.controller?.value = const TextEditingValue(
      text: "carry onward",
      selection: TextSelection.collapsed(offset: 12),
    );
    expect(busy, [true, false, true, false]);

    // Send ends a composed word, but reports it settled only after the sent
    // draft is cleared, so an outcome that report releases is not wiped.
    field.controller?.value = const TextEditingValue(
      text: "carry onward and",
      selection: TextSelection.collapsed(offset: 16),
      composing: TextRange(start: 13, end: 16),
    );
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();
    expect(busyWhenCleared, [
      [true, false, true, false, true],
    ]);
    expect(busy, [true, false, true, false, true, false]);

    // A pick that settles after the composer is gone reports nothing.
    picker.result = Completer();
    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(_tooltip("Attach image"));
    await tester.pump();
    expect(busy, [true, false, true, false, true, false, true]);
    await tester.pumpWidget(const SizedBox());
    picker.result.complete(null);
    await tester.pump();
    expect(busy, [true, false, true, false, true, false, true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets("dropped paths stage images and type the rest at the caret on a local bridge", (tester) async {
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
    addTearDown(surfaceStyle.dispose);
    final drops = StreamController<List<String>>();
    addTearDown(drops.close);
    final root = Directory.systemTemp.createTempSync("composer_drop_test");
    addTearDown(() => root.deleteSync(recursive: true));
    final png = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);
    final imagePath = (File("${root.path}/shot.png")..writeAsBytesSync(png)).path;
    final notesPath = (File("${root.path}/notes.dart")..writeAsStringSync("void main() {}")).path;
    final dispatcher = composerAttachmentDispatcherForTest(
      filePicker: const NoOpComposerFilePicker(),
      downscaleBuilder: const ComposerImageDownscaleBuilder(),
      bridgeIsLocal: true,
    );
    final clipboard = _NoOpImageClipboard();
    final reportedAttachments = <List<ComposerAttachment>>[];
    final busy = <bool>[];
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
          presentation: ComposerPresentation.pointer,
          attachmentDispatcher: () => dispatcher,
          imageClipboard: () => clipboard,
          droppedPaths: drops.stream,
          attachKind: ComposerAttachKind.images,
          child: Scaffold(
            body: PromptInput(
              initialSelection: (base: 3, extent: 3),
              onBusyChanged: busy.add,
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
              draftIdentity: "drop-session",
              restorationKey: null,
              initialDraft: ComposerDraft.typed(text: "see and fix"),
              initialAttachments: const [],
              onAttachmentsChanged: reportedAttachments.add,
              autofocus: false,
              onInitialAttachmentsConsumed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    drops.add([notesPath, imagePath]);
    await tester.pump();
    expect(busy, [true]);
    // Real file reads only finish outside the fake clock.
    for (var tries = 0; tries < 100 && busy.last; tries++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, "see $notesPath and fix");
    expect(reportedAttachments.last.single.filename, "shot.png");
    expect(tester.takeException(), isNull);
  });

  testWidgets("a drop turned away for several reasons gets one notice naming each", (tester) async {
    final drops = StreamController<List<String>>();
    addTearDown(drops.close);
    final root = Directory.systemTemp.createTempSync("composer_drop_reasons_test");
    addTearDown(() => root.deleteSync(recursive: true));
    final png = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);
    final imagePath = (File("${root.path}/shot.png")..writeAsBytesSync(png)).path;
    final notesPath = (File("${root.path}/notes.dart")..writeAsStringSync("void main() {}")).path;
    final libPath = (Directory("${root.path}/lib")..createSync()).path;
    await _pumpAttachComposer(
      tester: tester,
      dispatcher: composerAttachmentDispatcherForTest(
        filePicker: const NoOpComposerFilePicker(),
        downscaleBuilder: const ComposerImageDownscaleBuilder(),
        bridgeIsLocal: false,
      ),
      clipboard: _NoOpImageClipboard(),
      droppedPaths: drops.stream,
      voiceCubit: null,
      attachmentsSupported: false,
      onAttachmentsChanged: (_) {},
    );

    drops.add([notesPath, imagePath, libPath]);
    await _settleFileReads(tester);

    expect(
      find.text(
        "2 files weren't added. Only images can be sent to another computer for now.\n"
        "An image wasn't added. This agent doesn't accept images.",
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets("drops pause while recording and resume once it settles", (tester) async {
    final drops = StreamController<List<String>>();
    addTearDown(drops.close);
    final voiceStates = StreamController<VoiceInputState>();
    addTearDown(voiceStates.close);
    final voiceCubit = _MockVoiceInputCubit();
    whenListen(voiceCubit, voiceStates.stream, initialState: const VoiceInputState.idle());
    when(() => voiceCubit.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    addTearDown(voiceCubit.close);
    await _pumpAttachComposer(
      tester: tester,
      dispatcher: composerAttachmentDispatcherForTest(
        filePicker: const NoOpComposerFilePicker(),
        downscaleBuilder: const ComposerImageDownscaleBuilder(),
        bridgeIsLocal: true,
      ),
      clipboard: _NoOpImageClipboard(),
      droppedPaths: drops.stream,
      voiceCubit: voiceCubit,
      attachmentsSupported: true,
      onAttachmentsChanged: (_) {},
    );
    expect(drops.isPaused, isFalse);

    voiceStates.add(const VoiceInputState.recording());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(drops.isPaused, isTrue);

    voiceStates.add(const VoiceInputState.idle());
    await tester.pumpAndSettle();
    expect(drops.isPaused, isFalse);
  });

  testWidgets("two pasted images stage in paste order when the first downscales slower", (tester) async {
    final first = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 1]);
    final second = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 2]);
    final downscale = _QueuedDownscaleBuilder();
    final reportedAttachments = <List<ComposerAttachment>>[];
    await _pumpAttachComposer(
      tester: tester,
      dispatcher: composerAttachmentDispatcherForTest(
        filePicker: const NoOpComposerFilePicker(),
        downscaleBuilder: downscale,
        bridgeIsLocal: false,
      ),
      clipboard: _QueuedImageClipboard(images: [first, second]),
      droppedPaths: null,
      voiceCubit: null,
      attachmentsSupported: true,
      onAttachmentsChanged: reportedAttachments.add,
    );

    await tester.showKeyboard(find.byType(EditableText));
    final actionContext = FocusManager.instance.primaryFocus?.context ?? fail("the composer field is not focused");
    Actions.invoke(actionContext, const PasteTextIntent(SelectionChangedCause.keyboard));
    await tester.pump();
    Actions.invoke(actionContext, const PasteTextIntent(SelectionChangedCause.keyboard));
    await tester.pump();
    expect(downscale.results, hasLength(2));

    downscale.results[1].complete(const ComposerImageKept());
    await tester.pump();
    expect(reportedAttachments.where((attachments) => attachments.isNotEmpty), isEmpty);

    downscale.results[0].complete(const ComposerImageKept());
    await tester.pumpAndSettle();
    expect([for (final attachment in reportedAttachments.last) attachment.bytes], [first, second]);
  });

  testWidgets("staged previews scroll, remove the selected image, and send original remaining bytes", (tester) async {
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
    addTearDown(surfaceStyle.dispose);
    final dispatcher = composerAttachmentDispatcherForTest(
      filePicker: const NoOpComposerFilePicker(),
      downscaleBuilder: const ComposerImageDownscaleBuilder(),
      bridgeIsLocal: false,
    );
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
          presentation: ComposerPresentation.touch,
          attachmentDispatcher: () => dispatcher,
          imageClipboard: () => clipboard,
          droppedPaths: null,
          attachKind: ComposerAttachKind.images,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: PromptInput(
                  initialSelection: null,
                  onBusyChanged: null,
                  onSelectionChanged: null,
                  isBusy: false,
                  hasMessages: false,
                  canSend: true,
                  onSend: ({required draft, required command, required attachments}) => sent = attachments,
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
                  draftIdentity: "preview-session",
                  restorationKey: null,
                  initialDraft: ComposerDraft.typed(text: ""),
                  initialAttachments: images,
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
    final strip = find.byType(PregoImageAttachmentStrip);
    expect(tester.getSize(strip).height, 52);
    expect(find.byType(PregoImageAttachmentPreview), findsNWidgets(8));
    final firstImage = tester.widget<Image>(find.descendant(of: strip, matching: find.byType(Image)).first);
    expect(firstImage.fit, BoxFit.cover);
    expect((firstImage.image as ResizeImage).width, 156);
    // Like the new session page, no session scope: a staged image still opens.
    await tester.tap(find.byKey(ObjectKey(images.first)));
    await tester.pumpAndSettle();
    expect(find.byType(ImageAttachmentViewer), findsOneWidget);
    await tester.tap(find.byTooltip("Close image"));
    await tester.pumpAndSettle();
    expect(find.byType(ImageAttachmentViewer), findsNothing);
    expect(find.byType(PregoImageAttachmentPreview), findsNWidgets(8));
    await tester.drag(strip, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(ObjectKey(images.last)), matching: find.byIcon(TablerRegular.x)));
    await tester.pumpAndSettle();
    expect(find.byKey(ObjectKey(images.last)), findsNothing);
    expect(find.byType(PregoImageAttachmentPreview), findsNWidgets(7));
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pumpAndSettle();
    final sentImages = sent;
    expect(sentImages, orderedEquals(images.take(7)));
    if (sentImages == null) fail("No images were sent.");
    for (var i = 0; i < sentImages.length; i++) {
      expect(identical(sentImages[i].bytes, images[i].bytes), isTrue);
    }
    expect(strip, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("restored attachments over the aggregate budget stage only what fits and show the notice", (
    tester,
  ) async {
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
    addTearDown(surfaceStyle.dispose);
    final dispatcher = composerAttachmentDispatcherForTest(
      filePicker: const NoOpComposerFilePicker(),
      downscaleBuilder: const ComposerImageDownscaleBuilder(),
      bridgeIsLocal: false,
    );
    final clipboard = _NoOpImageClipboard();
    // Each fits alone; the three together exceed the 50 MB aggregate budget.
    final images = [
      for (var i = 0; i < 3; i++)
        ComposerAttachment(
          mime: "image/png",
          bytes: Uint8List(maxComposerPromptAttachmentBytes * 2 ~/ 5),
          filename: "Photo $i.png",
        ),
    ];
    var consumed = false;
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
          droppedPaths: null,
          attachKind: ComposerAttachKind.images,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
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
                  draftIdentity: "restored-session",
                  restorationKey: null,
                  initialDraft: ComposerDraft.typed(text: "Restored"),
                  initialAttachments: images,
                  onAttachmentsChanged: null,
                  autofocus: false,
                  onInitialAttachmentsConsumed: () => consumed = true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PregoImageAttachmentPreview), findsNWidgets(2));
    expect(find.byKey(ObjectKey(images.last)), findsNothing);
    expect(find.text("Attached images are limited to 50 MB per message."), findsOneWidget);
    expect(consumed, isTrue);
    await tester.pumpAndSettle(const Duration(seconds: 10));
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
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);
    // The trailing slot stays while the chip stands in for the header.
    expect(find.text("Picker header"), findsNothing);
    expect(find.text("Sub-agents"), findsOneWidget);

    await tester.tap(find.byIcon(TablerRegular.x));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(command.value, isNull);
    expect(find.byType(GlassMaterializeTransition), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(GlassMaterializeTransition), findsNothing);
    expect(find.text("Picker header"), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, "Keep this draft");
    // The chip sits outside the editor tap region: clearing already dismissed
    // focus before the transition change. Staging still focuses the editor.
    expect(
      (tester.widget<TextField>(find.byType(TextField)).focusNode ?? fail("The field has no focus node.")).hasFocus,
      isFalse,
    );

    command.value = _stagedCommand;
    await tester.pumpAndSettle();
    voiceStates.add(const VoiceInputState.recording());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey("release-hint")), findsOneWidget);
    expect(find.text("Sub-agents"), findsOneWidget);
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

    voiceStates.add(VoiceInputState.retryPending(error: VoiceTranscriptionError.networkError(innerError: null)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey("saved-recording-actions")), findsOneWidget);
    expect(find.text("Sub-agents"), findsOneWidget);
    expect(find.byType(GlassMaterializeTransition), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, "Keep this draft");
  }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS}));

  for (final (name, features, fadeMs) in const [
    ("iOS Reduce Motion", FakeAccessibilityFeatures(reduceMotion: true), 220),
    ("Android Remove animations", FakeAccessibilityFeatures(disableAnimations: true), 11),
  ]) {
    testWidgets("$name keeps the staged chip's fade, without its scale or the slot's easing", (tester) async {
      final command = ValueNotifier<CommandInfo?>(null);
      addTearDown(command.dispose);
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pumpCommandComposer(
        tester: tester,
        command: command,
        voiceCubit: null,
        disableAnimations: features.disableAnimations,
      );
      await tester.pumpAndSettle();
      final transition = find.byType(GlassMaterializeTransition);
      void expectPlainFade({required int ms}) {
        final progress = (ms / fadeMs).clamp(0.0, 1.0);
        expect(tester.widget<GlassMaterializeTransition>(transition).animation.value, closeTo(progress, 0.01));
        final scale = find.descendant(of: transition, matching: find.byType(Transform)).first;
        expect(tester.widget<Transform>(scale).transform, Matrix4.identity(), reason: "Scaled at $ms ms");
      }

      command.value = _stagedCommand;
      await tester.pump();
      expect(
        find.ancestor(of: find.byType(AnimatedSwitcher).first, matching: find.byType(AnimatedSize)),
        findsNothing,
        reason: "The slot takes its new height at once.",
      );
      expect(find.text("Picker header"), findsOneWidget, reason: "It leaves on a fade rather than at once.");
      for (var ms = 16; ms <= fadeMs; ms += 16) {
        await tester.pump(const Duration(milliseconds: 16));
        expectPlainFade(ms: ms);
      }
      await tester.pumpAndSettle();
      expect(find.byType(GlassChip), findsOneWidget);
      expect(find.text("Picker header"), findsNothing);

      await tester.tap(find.byIcon(TablerRegular.x));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      if (fadeMs > 16) {
        expect(tester.widget<GlassMaterializeTransition>(transition).animation.value, closeTo(1 - 16 / fadeMs, 0.01));
      }
      await tester.pumpAndSettle();
      expect(find.byType(GlassChip), findsNothing);
      expect(find.text("Picker header"), findsOneWidget);
    });
  }

  testWidgets("turning on Remove animations mid-draft keeps the input and its focus", (tester) async {
    final command = ValueNotifier<CommandInfo?>(null);
    addTearDown(command.dispose);
    await _pumpCommandComposer(tester: tester, command: command, voiceCubit: null, disableAnimations: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final editor = tester.state(find.byType(EditableText));

    await _pumpCommandComposer(tester: tester, command: command, voiceCubit: null, disableAnimations: true);
    await tester.pump();

    expect(tester.state(find.byType(EditableText)), same(editor));
    expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);
  });

  testWidgets("unsupported voice forces a text-first composer without a VoiceInputCubit", (tester) async {
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
    addTearDown(surfaceStyle.dispose);
    final attachmentDispatcher = composerAttachmentDispatcherForTest(
      filePicker: const NoOpComposerFilePicker(),
      downscaleBuilder: const ComposerImageDownscaleBuilder(),
      bridgeIsLocal: false,
    );
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
          presentation: ComposerPresentation.touch,
          attachmentDispatcher: () => attachmentDispatcher,
          imageClipboard: () => imageClipboard,
          droppedPaths: null,
          attachKind: ComposerAttachKind.images,
          child: Scaffold(
            body: PromptInput(
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
              draftIdentity: "desktop-session",
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
    );
    await tester.pumpAndSettle();

    expect(find.text("Ask anything..."), findsOneWidget);
    expect(find.byIcon(TablerRegular.microphone), findsNothing);

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    expect(_tooltip("Attach image"), findsOneWidget);
    expect(_tooltip("More actions"), findsNothing);
  });

  testWidgets("defers surface-style synchronization while dependencies rebuild", (tester) async {
    final inputMode = ValueNotifier(ChatInputMode.textFirst);
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.emphasized);
    final attachmentDispatcher = composerAttachmentDispatcherForTest(
      filePicker: const NoOpComposerFilePicker(),
      downscaleBuilder: const ComposerImageDownscaleBuilder(),
      bridgeIsLocal: false,
    );
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
              presentation: ComposerPresentation.touch,
              attachmentDispatcher: () => attachmentDispatcher,
              imageClipboard: () => imageClipboard,
              droppedPaths: null,
              attachKind: ComposerAttachKind.images,
              child: Scaffold(
                body: Column(
                  children: [
                    ValueListenableBuilder<PregoComposerSurfaceStyle>(
                      valueListenable: surfaceStyle,
                      builder: (context, style, _) => Text(style.name),
                    ),
                    PromptInput(
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
                      draftIdentity: "mobile-session",
                      restorationKey: null,
                      initialDraft: ComposerDraft.typed(text: ""),
                      initialAttachments: const [],
                      onAttachmentsChanged: null,
                      autofocus: false,
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
  testWidgets("a pasted image still being prepared does not land in the composer that replaced it", (tester) async {
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
    addTearDown(surfaceStyle.dispose);
    final draftIdentity = ValueNotifier("first-session");
    addTearDown(draftIdentity.dispose);
    final downscale = _PendingDownscaleBuilder();
    final dispatcher = composerAttachmentDispatcherForTest(
      filePicker: const NoOpComposerFilePicker(),
      downscaleBuilder: downscale,
      bridgeIsLocal: false,
    );
    final png = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);
    final clipboard = _FixedImageClipboard(bytes: png);
    final reportedAttachments = <List<ComposerAttachment>>[];
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
          droppedPaths: null,
          attachKind: ComposerAttachKind.images,
          child: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: draftIdentity,
              builder: (context, identity, _) => PromptInput(
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
                draftIdentity: identity,
                restorationKey: null,
                initialDraft: ComposerDraft.typed(text: "see attached"),
                initialAttachments: const [],
                onAttachmentsChanged: reportedAttachments.add,
                autofocus: false,
                onInitialAttachmentsConsumed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.showKeyboard(find.byType(EditableText));
    final actionContext = FocusManager.instance.primaryFocus?.context ?? fail("the composer field is not focused");
    Actions.invoke(actionContext, const PasteTextIntent(SelectionChangedCause.keyboard));
    await tester.pump();

    draftIdentity.value = "second-session";
    await tester.pump();
    downscale.result.complete(const ComposerImageKept());
    await tester.pumpAndSettle();

    expect(reportedAttachments.where((attachments) => attachments.isNotEmpty), isEmpty);
    expect(find.bySemanticsLabel("Attached image"), findsNothing);
    expect(tester.takeException(), isNull);
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
  final attachmentDispatcher = composerAttachmentDispatcherForTest(
    filePicker: const NoOpComposerFilePicker(),
    downscaleBuilder: const ComposerImageDownscaleBuilder(),
    bridgeIsLocal: false,
  );
  final imageClipboard = _NoOpImageClipboard();
  final composer = ValueListenableBuilder<CommandInfo?>(
    valueListenable: command,
    builder: (context, staged, _) => ComposerPresentationScope(
      voiceSupport: voiceCubit == null ? ComposerVoiceSupport.unsupported : ComposerVoiceSupport.supported,
      inputMode: ChatInputMode.textFirst,
      isKeyboardVisible: false,
      sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
      presentation: ComposerPresentation.touch,
      attachmentDispatcher: () => attachmentDispatcher,
      imageClipboard: () => imageClipboard,
      droppedPaths: null,
      attachKind: ComposerAttachKind.images,
      child: Scaffold(
        body: PromptInput(
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
          composerHeader: const Text("Picker header"),
          composerTrailing: const Text("Sub-agents"),
          availableCommands: const [_stagedCommand],
          stagedCommand: staged,
          onCommandSelected: (_) {},
          onCommandCleared: () => command.value = null,
          attachmentsSupported: false,
          draftIdentity: "glass-command-test",
          restorationKey: null,
          initialDraft: ComposerDraft.typed(text: "Initial draft"),
          initialAttachments: const [],
          onAttachmentsChanged: null,
          autofocus: false,
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

Future<void> _pumpAttachComposer({
  required WidgetTester tester,
  required ComposerAttachmentDispatcher dispatcher,
  required ImageClipboard clipboard,
  required Stream<List<String>>? droppedPaths,
  required VoiceInputCubit? voiceCubit,
  required bool attachmentsSupported,
  required ValueChanged<List<ComposerAttachment>> onAttachmentsChanged,
}) async {
  final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
  addTearDown(surfaceStyle.dispose);
  final composer = ComposerPresentationScope(
    voiceSupport: voiceCubit == null ? ComposerVoiceSupport.unsupported : ComposerVoiceSupport.supported,
    inputMode: ChatInputMode.textFirst,
    isKeyboardVisible: false,
    sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
    presentation: ComposerPresentation.touch,
    attachmentDispatcher: () => dispatcher,
    imageClipboard: () => clipboard,
    droppedPaths: droppedPaths,
    attachKind: ComposerAttachKind.files,
    child: Scaffold(
      body: PromptInput(
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
        attachmentsSupported: attachmentsSupported,
        draftIdentity: "attach-session",
        restorationKey: null,
        initialDraft: ComposerDraft.typed(text: "see attached"),
        initialAttachments: const [],
        onAttachmentsChanged: onAttachmentsChanged,
        autofocus: false,
        onInitialAttachmentsConsumed: () {},
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: voiceCubit == null ? composer : BlocProvider<VoiceInputCubit>.value(value: voiceCubit, child: composer),
    ),
  );
  await tester.pump();
}

/// Real file reads only finish outside the fake clock.
Future<void> _settleFileReads(WidgetTester tester) async {
  for (var tries = 0; tries < 20; tries++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
}
