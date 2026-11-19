import "dart:typed_data";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/composer_attachment_dispatcher_fixture.dart";
import "../../helpers/trackpad_overscroll.dart";

class _MockNewSessionCubit() extends MockCubit<NewSessionState> implements NewSessionCubit;
class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;
class _MockChatInputModeCubit() extends MockCubit<ChatInputMode> implements ChatInputModeCubit;

class _NoOpImageClipboard() implements ImageClipboard {
  @override
  Future<Uint8List?> readImage() async => null;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {}
}

const _project = NewSessionProject(id: "fixture-project", name: "Fixture", kind: ProjectKind.folder);

const _composing = NewSessionState.composing(
  project: _project,
  config: NewSessionComposeConfig(
    availablePlugins: [],
    selectedPlugin: null,
    supportsFileUploads: true,
    options: NewSessionOptionsLoadState.unsupported(),
    backendScope: NewSessionBackendScope.verified(bridgeId: null),
    isPluginDiscoveryInFlight: false,
    projectWorktreeCapability: NewSessionProjectWorktreeCapability.supported,
  ),
  phase: NewSessionPhase.idle(),
);

void main() {
  _MockNewSessionCubit composerCubit({required List<ComposerAttachment> initialAttachments}) {
    final composer = _MockNewSessionCubit();
    whenListen(composer, const Stream<NewSessionState>.empty(), initialState: _composing);
    when(() => composer.needsHarnessDiscovery).thenReturn(false);
    when(() => composer.hasNoHarnesses).thenReturn(false);
    when(composer.readDedicatedWorktreePreference).thenAnswer((_) async => false);
    when(() => composer.canSubmit).thenReturn(true);
    when(() => composer.composerPresentation).thenReturn(const NewSessionComposerReady());
    when(() => composer.composerDraft).thenReturn(ComposerDraft.typed(text: "next idea"));
    when(() => composer.offersAttachments).thenReturn(true);
    when(() => composer.initialAttachments).thenReturn(initialAttachments);
    when(() => composer.composerDraftIdentity).thenReturn(ComposerDraftRepository.newSessionIdentity);
    return composer;
  }

  Future<void> pumpNewSession({
    required WidgetTester tester,
    required NewSessionCubit composer,
    required NewSessionPageChrome? pageChrome,
  }) async {
    final projects = _MockProjectListCubit();
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(projects: [], folderProjects: [], scratchProject: null),
    );
    final inputMode = _MockChatInputModeCubit();
    whenListen(inputMode, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.textFirst);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ProjectListCubit>.value(value: projects),
          BlocProvider<ChatInputModeCubit>.value(value: inputMode),
          BlocProvider<NewSessionCubit>.value(value: composer),
          BlocProvider(create: (_) => testBridgeKindCubit(kind: null)),
        ],
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NewSessionView(
            title: "New session",
            composingTitleMode: PregoTopNavigationTitleMode.inline,
            onProjectSelected: ({required projectId, required projectName}) {},
            onBack: null,
            onOpenHarnessSettings: () {},
            onSessionCreated: ({required session, required project}) {},
            composerScopeBuilder: ({required projectId, required child}) => ComposerPresentationScope(
              voiceSupport: ComposerVoiceSupport.unsupported,
              inputMode: ChatInputMode.textFirst,
              isKeyboardVisible: false,
              sendKeyPolicy: ComposerSendKeyPolicy.modifierEnterSends,
              presentation: ComposerPresentation.touch,
              attachmentDispatcher: () => composerAttachmentDispatcherForTest(
                filePicker: const NoOpComposerFilePicker(),
                downscaleBuilder: const ComposerImageDownscaleBuilder(),
                bridgeIsLocal: false,
              ),
              imageClipboard: _NoOpImageClipboard.new,
              fileClipboard: null,
              droppedPaths: null,
              attachKind: ComposerAttachKind.photosAndFiles,
              child: child,
            ),
            banner: null,
            pageChrome: pageChrome,
            aboveComposer: null,
            submitAction: null,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets("the composer opens with the attachments the last new-session composer kept", (tester) async {
    const kept = ComposerHostFileAttachment(path: "/tmp/notes.txt", filename: "notes.txt");
    final composer = composerCubit(initialAttachments: const [kept]);
    await pumpNewSession(tester: tester, composer: composer, pageChrome: null);

    expect(tester.widget<PromptInput>(find.byType(PromptInput)).initialAttachments, const [kept]);
    final staged = verify(
      () => composer.saveComposerAttachments(attachments: captureAny(named: "attachments")),
    ).captured;
    expect(staged.last, const [kept]);
    expect(find.byKey(const ObjectKey(kept)), findsOneWidget);
  });

  testWidgets("a trackpad overscroll stretches steadily while the composer slides under a resting cursor", (
    tester,
  ) async {
    // A short window, so the options column scrolls.
    tester.view.physicalSize = const Size(800, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpNewSession(
      tester: tester,
      composer: composerCubit(initialAttachments: const []),
      pageChrome: const NewSessionPageChrome(
        topBar: SizedBox(height: 48),
        maxContentWidth: 600,
        transcriptWidth: 600,
        backgroundColor: null,
      ),
    );

    await expectSteadyTrackpadOverscroll(tester: tester, target: find.byType(TextField));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
