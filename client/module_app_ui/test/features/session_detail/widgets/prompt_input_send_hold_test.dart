import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/composer_attachment_dispatcher_fixture.dart";

class _PendingImageClipboard() implements ImageClipboard {
  final read = Completer<Uint8List?>();

  @override
  Future<Uint8List?> readImage() => read.future;

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

typedef _Sent = ({String text, List<ComposerAttachment> attachments});

final _png = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);

void main() {
  Future<void> pumpComposer(
    WidgetTester tester, {
    required ImageClipboard clipboard,
    required ComposerImageDownscaleBuilder downscaleBuilder,
    required ValueNotifier<String> draftIdentity,
    required List<_Sent> sent,
  }) async {
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
    addTearDown(surfaceStyle.dispose);
    final dispatcher = composerAttachmentDispatcherForTest(
      filePicker: const NoOpComposerFilePicker(),
      downscaleBuilder: downscaleBuilder,
      bridgeIsLocal: false,
    );
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
                onSend: ({required draft, required command, required attachments}) =>
                    sent.add((text: draft.text, attachments: attachments)),
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
                onAttachmentsChanged: null,
                autofocus: false,
                onInitialAttachmentsConsumed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> paste(WidgetTester tester) async {
    await tester.showKeyboard(find.byType(EditableText));
    final actionContext = FocusManager.instance.primaryFocus?.context ?? fail("the composer field is not focused");
    Actions.invoke(actionContext, const PasteTextIntent(SelectionChangedCause.keyboard));
    await tester.pump();
  }

  Future<void> pressSend(WidgetTester tester) async {
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();
  }

  bool sendSpins(WidgetTester tester) => tester
      .widgetList<PregoButtonsSolid>(find.byType(PregoButtonsSolid))
      .any((button) => button.leadingIcon == TablerRegular.arrow_up && button.isLoading);

  testWidgets("Send waits, spinning, for an image being prepared and sends it once with the prompt", (tester) async {
    final draftIdentity = ValueNotifier("session");
    addTearDown(draftIdentity.dispose);
    final clipboard = _PendingImageClipboard();
    final downscale = _PendingDownscaleBuilder();
    final sent = <_Sent>[];
    await pumpComposer(
      tester,
      clipboard: clipboard,
      downscaleBuilder: downscale,
      draftIdentity: draftIdentity,
      sent: sent,
    );

    await paste(tester);
    clipboard.read.complete(_png);
    await tester.pump();
    await pressSend(tester);
    expect(sent, isEmpty);
    expect(sendSpins(tester), isTrue);

    // A second press while it waits does nothing.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, isEmpty);

    downscale.result.complete(const ComposerImageKept());
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(sent.single.text, "see attached");
    expect([for (final attachment in sent.single.attachments) attachment.bytes], [_png]);
    expect(sendSpins(tester), isFalse);
  });

  testWidgets("an image that fails to stage lets the held send go without it, with its notice", (tester) async {
    final draftIdentity = ValueNotifier("session");
    addTearDown(draftIdentity.dispose);
    final clipboard = _PendingImageClipboard();
    final sent = <_Sent>[];
    await pumpComposer(
      tester,
      clipboard: clipboard,
      downscaleBuilder: const ComposerImageDownscaleBuilder(),
      draftIdentity: draftIdentity,
      sent: sent,
    );

    await paste(tester);
    await pressSend(tester);
    expect(sent, isEmpty);

    // Not an image signature, so staging fails.
    clipboard.read.complete(Uint8List.fromList(List<int>.generate(16, (index) => index)));
    await tester.pump();
    await tester.pump();

    expect(sent.single.text, "see attached");
    expect(sent.single.attachments, isEmpty);
    expect(find.text("That image format isn't supported."), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets("moving to another draft while Send waits abandons that send", (tester) async {
    final draftIdentity = ValueNotifier("first-session");
    addTearDown(draftIdentity.dispose);
    final clipboard = _PendingImageClipboard();
    final downscale = _PendingDownscaleBuilder();
    final sent = <_Sent>[];
    await pumpComposer(
      tester,
      clipboard: clipboard,
      downscaleBuilder: downscale,
      draftIdentity: draftIdentity,
      sent: sent,
    );

    await paste(tester);
    clipboard.read.complete(_png);
    await tester.pump();
    await pressSend(tester);
    expect(sendSpins(tester), isTrue);

    draftIdentity.value = "second-session";
    await tester.pump();
    await tester.pump();
    expect(sendSpins(tester), isFalse);

    downscale.result.complete(const ComposerImageKept());
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
  });
}
