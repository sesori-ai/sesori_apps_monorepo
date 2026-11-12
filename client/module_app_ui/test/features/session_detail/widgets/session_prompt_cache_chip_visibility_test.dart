import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:clock/clock.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/session_prompt_cache_chip.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/composer_attachment_dispatcher_fixture.dart";

class _MockVoiceInputCubit() extends MockCubit<VoiceInputState> implements VoiceInputCubit;

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

/// Runs [callback] with `clock` reading the test's fake time.
void _clockTestWidgets(String description, WidgetTesterCallback callback) => testWidgets(
  description,
  (tester) => withClock(Clock(() => tester.binding.clock.now()), () => callback(tester)),
);

const _modelId = "claude-3-5-sonnet";

/// A loaded idle session whose agent replied a minute ago on a model with the
/// given [fastMode] support.
SessionDetailLoaded _state({required WidgetTester tester, required FastModeSupport? fastMode}) {
  final base = testProviderListResponse().items.first;
  final model = base.models[_modelId] ?? fail("The provider fixture has no $_modelId model.");
  final provider = base.copyWith(models: {_modelId: model.copyWith(fastMode: fastMode)});
  final repliedAt = tester.binding.clock.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch;
  return SessionDetailLoaded(
    interaction: const SessionInteractionState.available(displayName: "Claude Code", refreshError: null),
    messages: [
      MessageWithParts(
        info: Message.assistant(
          id: "msg-1",
          sessionID: "session-1",
          agent: "coder",
          modelID: _modelId,
          providerID: provider.id,
          time: MessageTime(created: repliedAt - 5000, completed: repliedAt),
        ),
        parts: const [],
      ),
    ],
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
    selectedAgentModel: AgentModel(providerID: provider.id, modelID: _modelId, variant: null),
    promptDefaults: null,
    fastMode: false,
    stagedCommand: null,
    isRefreshing: false,
    cannotContinueMessage: null,
  );
}

Future<void> _pumpControls({required WidgetTester tester, required SessionDetailLoaded state}) async {
  final voiceCubit = _MockVoiceInputCubit();
  addTearDown(voiceCubit.close);
  whenListen(voiceCubit, const Stream<VoiceInputState>.empty(), initialState: const VoiceInputState.idle());
  when(() => voiceCubit.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());

  final detailCubit = _MockSessionDetailCubit();
  addTearDown(detailCubit.close);
  whenListen(detailCubit, const Stream<SessionDetailState>.empty(), initialState: state);
  when(() => detailCubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
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
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SessionDetailComposerControls(
                projectId: "project-1",
                sessionId: "session-1",
                source: LoadedSessionComposerSource(state: state),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() {
    registerFallbackValue(ComposerDraft.typed(text: ""));
    registerFallbackValue(<ComposerAttachment>[]);
  });

  const available = FastModeSupport.available(promptCacheTtlSeconds: 1800);

  _clockTestWidgets("an idle session with a warm prompt cache shows the chip", (tester) async {
    await _pumpControls(
      tester: tester,
      state: _state(tester: tester, fastMode: available),
    );

    expect(find.byType(SessionPromptCacheChip), findsOneWidget);
    expect(find.descendant(of: find.byType(SessionPromptCacheChip), matching: find.text("29 min")), findsOneWidget);

    // Disposal cancels the chip's timer.
    await tester.pumpWidget(const SizedBox());
  });

  _clockTestWidgets("a busy session keeps the chip, reading warm while the turn uses the cache", (tester) async {
    await _pumpControls(
      tester: tester,
      state: _state(tester: tester, fastMode: available).copyWith(sessionStatus: const SessionStatus.busy(since: 1)),
    );

    expect(find.byType(SessionPromptCacheChip), findsOneWidget);
    expect(find.descendant(of: find.byType(SessionPromptCacheChip), matching: find.text("Warm")), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  _clockTestWidgets("a model without a known cache lifetime hides the chip", (tester) async {
    await _pumpControls(
      tester: tester,
      state: _state(tester: tester, fastMode: null),
    );

    expect(find.byType(SessionPromptCacheChip), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}

class _NoOpImageClipboard() implements ImageClipboard {
  @override
  Future<Uint8List?> readImage() async => null;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {}
}
