import "dart:async";
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

class _MockEditorCubit() extends MockCubit<ScheduledTaskEditorState> implements ScheduledTaskEditorCubit;
class _MockNewSessionCubit() extends MockCubit<NewSessionState> implements NewSessionCubit;
class _MockProjectListCubit() extends MockCubit<ProjectListState> implements ProjectListCubit;
class _MockChatInputModeCubit() extends MockCubit<ChatInputMode> implements ChatInputModeCubit;

class _NoOpImageClipboard() implements ImageClipboard {
  @override
  Future<Uint8List?> readImage() async => null;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {}
}

final _task = scheduledTaskFixture(id: "daily", name: "Morning summary");

ScheduledTaskEditorReady _ready({required ScheduledTaskEditorSave save}) => ScheduledTaskEditorReady(
  editing: _task,
  schedule: _task.definition.schedule,
  missedRunPolicy: TaskMissedRunPolicy.runWhenBack,
  runMode: const TaskRunMode.newSession(),
  approvalMode: TaskApprovalMode.ask,
  timeZone: "UTC",
  deviceTimeZone: "UTC",
  save: save,
);

const _project = NewSessionProject(id: "fixture-project", name: "Fixture", kind: ProjectKind.folder);

const _config = NewSessionComposeConfig(
  availablePlugins: [],
  selectedPlugin: null,
  supportsFileUploads: false,
  options: NewSessionOptionsLoadState.unsupported(),
  backendScope: NewSessionBackendScope.verified(bridgeId: null),
  isPluginDiscoveryInFlight: false,
  projectWorktreeCapability: NewSessionProjectWorktreeCapability.supported,
);

const _composing = NewSessionState.composing(project: _project, config: _config, phase: NewSessionPhase.idle());

const _submission = TaskComposerSubmission(
  project: _project,
  pluginId: "fixture",
  compactsOnRequest: true,
  agent: null,
  model: null,
  variant: null,
  fastMode: false,
  dedicatedWorktree: false,
  prompt: "Summarize yesterday",
  command: null,
);

void main() {
  setUpAll(() => registerFallbackValue(_submission));

  testWidgets("Save sends the composer's task and leaves once the computer confirms it", (tester) async {
    final editor = _MockEditorCubit();
    final editorStates = StreamController<ScheduledTaskEditorState>();
    addTearDown(editorStates.close);
    whenListen(editor, editorStates.stream, initialState: _ready(save: const ScheduledTaskEditorSaveIdle()));
    when(() => editor.save(submission: any(named: "submission"))).thenAnswer((_) async {});

    final composer = _MockNewSessionCubit();
    final composerStates = StreamController<NewSessionState>();
    addTearDown(composerStates.close);
    whenListen(composer, composerStates.stream, initialState: _composing);
    when(() => composer.needsHarnessDiscovery).thenReturn(false);
    when(() => composer.hasNoHarnesses).thenReturn(false);
    when(composer.readDedicatedWorktreePreference).thenAnswer((_) async => false);
    when(() => composer.canSubmit).thenReturn(true);
    when(() => composer.composerPresentation).thenReturn(const NewSessionComposerReady());
    when(() => composer.composerDraft).thenReturn(ComposerDraft.typed(text: "Summarize yesterday"));
    when(() => composer.offersAttachments).thenReturn(false);
    when(() => composer.composerDraftIdentity).thenReturn(ComposerDraftRepository.newSessionIdentity);
    final purposes = <NewSessionPurpose>[];

    final projects = _MockProjectListCubit();
    whenListen(
      projects,
      const Stream<ProjectListState>.empty(),
      initialState: const ProjectListState.loaded(projects: [], folderProjects: [], scratchProject: null),
    );
    final inputMode = _MockChatInputModeCubit();
    whenListen(inputMode, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.textFirst);

    var saved = 0;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ProjectListCubit>.value(value: projects),
          BlocProvider<ChatInputModeCubit>.value(value: inputMode),
          BlocProvider(create: (_) => testBridgeKindCubit(kind: null)),
        ],
        child: MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScheduledTaskEditorView(
            createCubit: () => editor,
            createComposerCubit: ({required purpose}) {
              purposes.add(purpose);
              return composer;
            },
            onBack: () {},
            onSaved: () => saved++,
            onOpenHarnessSettings: () {},
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
          ),
        ),
      ),
    );
    await tester.pump();

    // The composer opens on the task's own choices, saving with a Save task button.
    expect(purposes, [isA<NewSessionEditTask>()]);
    expect(tester.widget<PromptInput>(find.byType(PromptInput)).submitAction?.label, "Save task");
    expect(find.byKey(const Key("scheduled-task-editor-when")), findsOneWidget);

    composerStates.add(
      const NewSessionState.composing(
        project: _project,
        config: _config,
        phase: NewSessionPhase.taskSubmitted(submission: _submission),
      ),
    );
    await tester.pump();
    verify(() => editor.save(submission: _submission)).called(1);

    editorStates.add(_ready(save: const ScheduledTaskEditorSaving()));
    await tester.pump();
    expect(saved, 0);
    editorStates.add(_ready(save: ScheduledTaskEditorSaved(task: _task)));
    await tester.pump();
    expect(saved, 1);
  });
}
