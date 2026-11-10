import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/composer_attachment_dispatcher_fixture.dart";

class _MockVoiceInputCubit() extends MockCubit<VoiceInputState> implements VoiceInputCubit;

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

void main() {
  setUpAll(() {
    registerFallbackValue(ComposerDraft.typed(text: ""));
    registerFallbackValue(<ComposerAttachment>[]);
  });

  testWidgets("a stop's restoration puts the returned messages into the open composer", (tester) async {
    final voiceCubit = _MockVoiceInputCubit();
    addTearDown(voiceCubit.close);
    whenListen(voiceCubit, const Stream<VoiceInputState>.empty(), initialState: const VoiceInputState.idle());
    when(() => voiceCubit.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());

    final provider = testProviderListResponse().items.first;
    final initial = SessionDetailLoaded(
      interaction: const SessionInteractionState.available(displayName: "Claude Code", refreshError: null),
      messages: const [],
      launchHandoff: null,
      olderMessagesCursor: null,
      userMessagesBeforeOldest: null,
      promptIndex: null,
      streamingText: const {},
      sessionStatus: const SessionStatus.idle(),
      pendingQuestions: const [],
      pendingPermissions: const [],
      sessionTitle: "Session",
      session: testConstSession,
      pluginId: "claude",
      supportsPromptAttachments: true,
      supportsFileUploads: false,
      offersSessionMcp: true,
      assistantAgentModel: null,
      children: const [],
      childStatuses: const {},
      isRootSession: true,
      isArchived: false,
      queuedMessages: const [],
      bridgePromptAttachments: const {},
      localSend: const LocalSendPhase.idle(),
      availableAgents: [testAgentInfo()],
      availableProviders: [provider],
      availableCommands: const [],
      selectedAgent: "coder",
      selectedAgentModel: AgentModel(providerID: provider.id, modelID: "model", variant: null),
      promptDefaults: null,
      fastMode: false,
      stagedCommand: null,
      isRefreshing: false,
      cannotContinueMessage: null,
    );

    final detailStates = StreamController<SessionDetailState>();
    addTearDown(detailStates.close);
    final detailCubit = _MockSessionDetailCubit();
    addTearDown(detailCubit.close);
    whenListen(detailCubit, detailStates.stream, initialState: initial);
    var draft = ComposerDraft.typed(text: "half typed");
    when(() => detailCubit.composerDraft).thenAnswer((_) => draft);
    when(() => detailCubit.saveComposerDraft(draft: any(named: "draft"))).thenReturn(null);
    when(detailCubit.clearComposerDraft).thenReturn(null);
    when(() => detailCubit.restoredAttachments).thenReturn(const []);
    when(detailCubit.acknowledgeRestoredAttachments).thenReturn(null);
    when(() => detailCubit.trackComposerAttachments(attachments: any(named: "attachments"))).thenReturn(null);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<VoiceInputCubit>.value(value: voiceCubit),
            BlocProvider<SessionDetailCubit>.value(value: detailCubit),
          ],
          child: ComposerPresentationScope(
            voiceSupport: ComposerVoiceSupport.supported,
            inputMode: ChatInputMode.textFirst,
            isKeyboardVisible: false,
            sendKeyPolicy: ComposerSendKeyPolicy.modifierEnterSends,
            presentation: ComposerPresentation.pointer,
            attachmentDispatcher: () => composerAttachmentDispatcherForTest(
              filePicker: const NoOpComposerFilePicker(),
              downscaleBuilder: const ComposerImageDownscaleBuilder(),
              bridgeIsLocal: false,
            ),
            imageClipboard: _NoOpImageClipboard.new,
            fileClipboard: null,
            droppedPaths: null,
            attachKind: ComposerAttachKind.photosAndFiles,
            child: Scaffold(
              body: BlocBuilder<SessionDetailCubit, SessionDetailState>(
                builder: (context, state) => Align(
                  alignment: Alignment.bottomCenter,
                  child: SessionDetailComposerControls(
                    projectId: "project-1",
                    sessionId: "session-1",
                    source: LoadedSessionComposerSource(state: state is SessionDetailLoaded ? state : initial),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text("half typed"), findsOneWidget);
    clearInteractions(detailCubit);

    // The stop folded the queued message ahead of what the composer held.
    draft = ComposerDraft.typed(text: "steer it\n\nhalf typed");
    detailStates.add(initial.copyWith(composerRestorations: 1));
    await tester.pump();
    await tester.pump();

    expect(find.text("steer it\n\nhalf typed"), findsOneWidget);
    verify(detailCubit.acknowledgeRestoredAttachments).called(1);
  });
}

class _NoOpImageClipboard() implements ImageClipboard {
  @override
  Future<Uint8List?> readImage() async => null;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {}
}
