import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/features/sessions/desktop_session_detail_screen.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

class _MockMessageImageRepository() extends Mock implements MessageImageRepository;

class _MockImageSaver() extends Mock implements ImageSaver;

class _MockImageClipboard() extends Mock implements ImageClipboard;

class _MockImageSharer() extends Mock implements ImageSharer;

const _question = SesoriQuestionAsked(
  id: "question-1",
  sessionID: "session-1",
  displaySessionId: null,
  questions: [
    QuestionInfo(
      question: "Choose a release channel",
      header: "Release channel",
      options: [QuestionOption(label: "Stable", description: "Release to everyone")],
      multiple: false,
      custom: false,
    ),
  ],
);

const _child = Session(
  branchName: null,
  id: "child-1",
  pluginId: "opencode",
  projectID: "project-1",
  directory: "/project",
  parentID: "session-1",
  title: "Child session",
  pullRequest: null,
  time: SessionTime(created: 1700000000000, updated: 1700000000000, archived: null),
  promptDefaults: null,
  lastUserActivityAt: null,
);

const _message = MessageWithParts(
  info: Message.assistant(
    id: "message-1",
    sessionID: "session-1",
    agent: null,
    modelID: null,
    providerID: null,
    time: null,
  ),
  parts: [
    MessagePart.text(
      id: "part-1",
      sessionID: "session-1",
      messageID: "message-1",
      text: "Desktop transcript",
    ),
    MessagePart.subtask(
      id: "part-2",
      sessionID: "session-1",
      messageID: "message-1",
      prompt: "Inspect the child",
      description: "Child session",
      agent: "explore",
      taskState: null,
      childSessionID: "child-1",
    ),
  ],
);

SessionDetailLoaded _loadedState() {
  return const SessionDetailLoaded(
    messages: [_message],
    olderMessagesCursor: null,
    streamingText: {},
    sessionStatus: SessionStatus.idle(),
    pendingQuestions: [_question],
    pendingPermissions: [],
    sessionTitle: "Desktop session",
    pluginId: "opencode",
    supportsPromptAttachments: true,
    agent: null,
    assistantAgentModel: null,
    children: [_child],
    childStatuses: {"child-1": SessionStatus.idle()},
    isRootSession: true,
    isArchived: false,
    queuedMessages: [],
    sendingSubmission: null,
    availableAgents: [],
    availableProviders: [],
    availableCommands: [],
    selectedAgent: "coder",
    selectedAgentModel: null,
    stagedCommand: null,
    isRefreshing: false,
  );
}

void main() {
  testWidgets("desktop renders an interactive transcript without composer controls", (tester) async {
    final cubit = _MockSessionDetailCubit();
    final state = _loadedState();
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);
    when(() => cubit.questionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.permissionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.noticeStream).thenAnswer((_) => const Stream.empty());
    when(cubit.clearNotifications).thenReturn(null);

    await tester.pumpWidget(
      BlocProvider<SessionDetailCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DesktopSessionDetailView(
            projectId: "project-1",
            sessionId: "session-1",
            sessionTitle: "Desktop session",
            readOnly: false,
            onBack: () {},
            onOpenSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
            messageImageRepository: _MockMessageImageRepository(),
            imageSaver: _MockImageSaver(),
            imageClipboard: _MockImageClipboard(),
            imageSharer: _MockImageSharer(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Desktop transcript"), findsOneWidget);
    final loadedView = tester.widget<SessionDetailLoadedView>(find.byType(SessionDetailLoadedView));
    expect(loadedView.readOnly, isFalse);
    expect(loadedView.bottomControls, isNull);

    await tester.tap(find.text("1 pending question"));
    await tester.pumpAndSettle();

    expect(find.text("Choose a release channel"), findsOneWidget);
  });

  testWidgets("desktop delegates Back and child-session navigation", (tester) async {
    final cubit = _MockSessionDetailCubit();
    final state = _loadedState();
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);
    when(() => cubit.questionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.permissionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.noticeStream).thenAnswer((_) => const Stream.empty());
    when(cubit.clearNotifications).thenReturn(null);
    var backCalls = 0;
    ({String projectId, String sessionId, String? sessionTitle, bool readOnly})? openedSession;

    await tester.pumpWidget(
      BlocProvider<SessionDetailCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DesktopSessionDetailView(
            projectId: "project-1",
            sessionId: "session-1",
            sessionTitle: "Desktop session",
            readOnly: false,
            onBack: () => backCalls++,
            onOpenSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) =>
                openedSession = (
                  projectId: projectId,
                  sessionId: sessionId,
                  sessionTitle: sessionTitle,
                  readOnly: readOnly,
                ),
            messageImageRepository: _MockMessageImageRepository(),
            imageSaver: _MockImageSaver(),
            imageClipboard: _MockImageClipboard(),
            imageSharer: _MockImageSharer(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel("Back"));
    expect(backCalls, 1);

    await tester.tap(find.text("Child session"));
    expect(
      openedSession,
      (
        projectId: "project-1",
        sessionId: "child-1",
        sessionTitle: "Child session",
        readOnly: true,
      ),
    );
  });
}
