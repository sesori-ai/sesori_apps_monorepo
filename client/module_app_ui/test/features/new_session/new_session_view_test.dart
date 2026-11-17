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
  testWidgets("the composer opens with the attachments the last new-session composer kept", (tester) async {
    const kept = ComposerHostFileAttachment(path: "/tmp/notes.txt", filename: "notes.txt");
    final composer = _MockNewSessionCubit();
    whenListen(composer, const Stream<NewSessionState>.empty(), initialState: _composing);
    when(() => composer.needsHarnessDiscovery).thenReturn(false);
    when(() => composer.hasNoHarnesses).thenReturn(false);
    when(composer.readDedicatedWorktreePreference).thenAnswer((_) async => false);
    when(() => composer.canSubmit).thenReturn(true);
    when(() => composer.composerPresentation).thenReturn(const NewSessionComposerReady());
    when(() => composer.composerDraft).thenReturn(ComposerDraft.typed(text: "next idea"));
    when(() => composer.offersAttachments).thenReturn(true);
    when(() => composer.initialAttachments).thenReturn(const [kept]);
    when(() => composer.composerDraftIdentity).thenReturn(ComposerDraftRepository.newSessionIdentity);

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
            pageChrome: null,
            aboveComposer: null,
            submitAction: null,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.widget<PromptInput>(find.byType(PromptInput)).initialAttachments, const [kept]);
    final staged = verify(
      () => composer.saveComposerAttachments(attachments: captureAny(named: "attachments")),
    ).captured;
    expect(staged.last, const [kept]);
    expect(find.byKey(const ObjectKey(kept)), findsOneWidget);
  });
}
