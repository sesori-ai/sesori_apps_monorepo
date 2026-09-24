import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/widgets/desktop_page_toolbar.dart";
import "package:sesori_desktop/core/widgets/desktop_session_signals.dart";
import "package:sesori_desktop/features/sessions/desktop_session_detail_screen.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

class _MockSessionListCubit() extends MockCubit<SessionListState> implements SessionListCubit;

class _MockMessageImageRepository() extends Mock implements MessageImageRepository;

class _MockImageSaver() extends Mock implements ImageSaver;

class _MockImageClipboard() extends Mock implements ImageClipboard;

class _MockImageSharer() extends Mock implements ImageSharer;

class _MockComposerAttachmentDispatcher() extends Mock implements ComposerAttachmentDispatcher;

const _actions = SessionListActionDispatcher(
  deleteConfirmation: SessionDeleteConfirmation.sheet,
  onSessionArchived: null,
  onSessionDeleted: null,
  onSessionMarkedUnread: null,
);

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
  autoContinuation: null,
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

/// A child session: the sidebar inventory never holds one, the page does.
const _session = Session(
  autoContinuation: null,
  branchName: null,
  id: "session-1",
  pluginId: "opencode",
  projectID: "project-1",
  directory: "/project",
  parentID: "parent-1",
  title: "Desktop session",
  pullRequest: null,
  time: SessionTime(created: 1700000000000, updated: 1700000000000, archived: null),
  promptDefaults: null,
  lastUserActivityAt: null,
  // Local state can still say unseen just after opening.
  unseen: true,
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

SessionDetailLoaded _loadedState({required Session session}) {
  return SessionDetailLoaded(
    interaction: const SessionInteractionState.available(displayName: "Claude Code", refreshError: null),
    messages: const [_message],
    olderMessagesCursor: null,
    streamingText: const {},
    sessionStatus: const SessionStatus.idle(),
    pendingQuestions: const [_question],
    pendingPermissions: const [],
    sessionTitle: "Desktop session",
    session: session,
    pluginId: "opencode",
    supportsPromptAttachments: true,
    assistantAgentModel: null,
    children: const [_child],
    childStatuses: const {"child-1": SessionStatus.idle()},
    isRootSession: true,
    isArchived: false,
    queuedMessages: const [],
    sendingSubmission: null,
    availableAgents: const [],
    availableProviders: const [],
    availableCommands: const [],
    selectedAgent: "coder",
    selectedAgentModel: null,
    fastMode: false,
    stagedCommand: null,
    isRefreshing: false,
  );
}

Widget _composerScope({required Widget child, required ComposerCapabilityProvider<ImageClipboard> imageClipboard}) {
  return ComposerPresentationScope(
    voiceSupport: ComposerVoiceSupport.unsupported,
    inputMode: ChatInputMode.textFirst,
    isKeyboardVisible: false,
    sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
    presentation: ComposerPresentation.pointer,
    attachmentDispatcher: _MockComposerAttachmentDispatcher.new,
    imageClipboard: imageClipboard,
    child: child,
  );
}

void main() {
  testWidgets("desktop renders the transcript and text-first composer", (tester) async {
    final cubit = _MockSessionDetailCubit();
    when(() => cubit.isRouteVisible).thenReturn(true);
    final state = _loadedState(session: _session);
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);
    when(() => cubit.questionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.permissionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.noticeStream).thenAnswer((_) => const Stream.empty());
    when(cubit.clearNotifications).thenReturn(null);
    when(() => cubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
    when(
      () => cubit.sendMessage(
        text: "Desktop follow-up",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      ),
    ).thenAnswer((_) async {});
    var messageImageRepositoryResolutions = 0;
    var imageSaverResolutions = 0;
    var imageClipboardResolutions = 0;
    var imageSharerResolutions = 0;
    var diffCalls = 0;

    await tester.pumpWidget(
      BlocProvider<SessionDetailCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _composerScope(
            imageClipboard: () {
              imageClipboardResolutions++;
              return _MockImageClipboard();
            },
            child: DesktopSessionDetailView(
              onOpenHarnessSettings: () {},
              projectId: "project-1",
              sessionId: "session-1",
              sessionTitle: "Desktop session",
              sessionActions: _actions,
              onMarkedUnread: () {},
              readOnly: false,
              projectName: "UI / Core",
              onOpenProject: () {},
              onOpenParentSession: ({required parentSessionId}) {},
              onShowDiffs: () => diffCalls++,
              onOpenSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
              messageImageRepository: () {
                messageImageRepositoryResolutions++;
                return _MockMessageImageRepository();
              },
              imageSaver: () {
                imageSaverResolutions++;
                return _MockImageSaver();
              },
              imageClipboard: () {
                imageClipboardResolutions++;
                return _MockImageClipboard();
              },
              imageSharer: () {
                imageSharerResolutions++;
                return _MockImageSharer();
              },
              canShareImages: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Desktop transcript"), findsOneWidget);
    expect(find.byKey(const Key("desktop-session-page-back")), findsNothing);
    expect(find.byIcon(TablerRegular.arrow_left), findsNothing);
    expect(find.byType(PregoReadableSelectionArea), findsOneWidget);
    final loadedView = tester.widget<SessionDetailLoadedView>(find.byType(SessionDetailLoadedView));
    expect(loadedView.readOnly, isFalse);
    expect(loadedView.bottomControls, isA<SessionDetailComposerControls>());
    expect(find.bySemanticsLabel("Start recording"), findsNothing);
    expect(messageImageRepositoryResolutions, 0);
    expect(imageSaverResolutions, 0);
    expect(imageClipboardResolutions, 0);
    expect(imageSharerResolutions, 0);

    await tester.tap(find.byIcon(TablerRegular.git_compare));
    expect(diffCalls, 1);

    await tester.tap(find.text("Follow up..."));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), "Desktop follow-up");
    await tester.pump();
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();
    verify(
      () => cubit.sendMessage(
        text: "Desktop follow-up",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      ),
    ).called(1);

    // `+` and `/` are always visible on desktop, and the box grows instead of
    // offering the editor sheet.
    expect(find.byTooltip("Attach image"), findsOneWidget);
    final composer = find.byType(SessionDetailComposerControls);
    expect(find.descendant(of: composer, matching: find.byIcon(TablerRegular.chevron_right)), findsNothing);
    expect(find.byIcon(TablerRegular.maximize), findsNothing);
    // The page toolbar's menu, not a composer one.
    expect(find.byTooltip("More actions"), findsOneWidget);

    await tester.tap(find.text("Answer"));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(QuestionModal), matching: find.text("Choose a release channel")),
      findsOneWidget,
    );
  });

  testWidgets("desktop delegates child-session navigation", (tester) async {
    final cubit = _MockSessionDetailCubit();
    when(() => cubit.isRouteVisible).thenReturn(true);
    final state = _loadedState(session: _session);
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);
    when(() => cubit.questionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.permissionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.noticeStream).thenAnswer((_) => const Stream.empty());
    when(cubit.clearNotifications).thenReturn(null);
    when(() => cubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
    ({String projectId, String sessionId, String? sessionTitle, bool readOnly})? openedSession;

    await tester.pumpWidget(
      BlocProvider<SessionDetailCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _composerScope(
            imageClipboard: _MockImageClipboard.new,
            child: DesktopSessionDetailView(
              onOpenHarnessSettings: () {},
              projectId: "project-1",
              sessionId: "session-1",
              sessionTitle: "Desktop session",
              sessionActions: _actions,
              onMarkedUnread: () {},
              readOnly: false,
              projectName: "UI / Core",
              onOpenProject: () {},
              onOpenParentSession: ({required parentSessionId}) {},
              onShowDiffs: () {},
              onOpenSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) =>
                  openedSession = (
                    projectId: projectId,
                    sessionId: sessionId,
                    sessionTitle: sessionTitle,
                    readOnly: readOnly,
                  ),
              messageImageRepository: _MockMessageImageRepository.new,
              imageSaver: _MockImageSaver.new,
              imageClipboard: _MockImageClipboard.new,
              imageSharer: _MockImageSharer.new,
              canShareImages: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

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

  group("page", () {
    late _MockSessionDetailCubit cubit;
    late _MockSessionListCubit listCubit;
    late List<Session> markedUnread;
    late int leftPage;
    late int openedProject;
    late List<String> openedParents;

    Future<void> pumpPage(WidgetTester tester, {required Session session}) async {
      cubit = _MockSessionDetailCubit();
      when(() => cubit.isRouteVisible).thenReturn(true);
      final state = _loadedState(session: session);
      when(() => cubit.state).thenReturn(state);
      whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);
      when(() => cubit.questionStream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.permissionStream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.noticeStream).thenAnswer((_) => const Stream.empty());
      when(cubit.clearNotifications).thenReturn(null);
      when(() => cubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
      listCubit = _MockSessionListCubit();
      when(() => listCubit.state).thenReturn(const SessionListState.loading());
      when(listCubit.retainActionScope).thenReturn(() {});
      when(
        () => listCubit.markSessionSeen(
          sessionId: any(named: "sessionId"),
          read: any(named: "read"),
        ),
      ).thenAnswer((_) async {});
      markedUnread = [];
      leftPage = 0;
      openedProject = 0;
      openedParents = [];
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SessionDetailCubit>.value(value: cubit),
            BlocProvider<SessionListCubit>.value(value: listCubit),
          ],
          // The desktop is a pointer surface: its menus draw shortcut labels.
          child: PregoInteractionScope(
            mode: PregoInteractionMode.pointer,
            child: MaterialApp(
              theme: ThemeData(extensions: [PregoDesignSystem.light]),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _composerScope(
                imageClipboard: _MockImageClipboard.new,
                child: DesktopSessionDetailView(
                  onOpenHarnessSettings: () {},
                  projectId: "project-1",
                  sessionId: "session-1",
                  sessionTitle: "Desktop session",
                  sessionActions: SessionListActionDispatcher(
                    deleteConfirmation: SessionDeleteConfirmation.sheet,
                    onSessionArchived: null,
                    onSessionDeleted: null,
                    onSessionMarkedUnread: ({required context, required session}) => markedUnread.add(session),
                  ),
                  onMarkedUnread: () => leftPage++,
                  readOnly: false,
                  projectName: "UI / Core",
                  onOpenProject: () => openedProject++,
                  onOpenParentSession: ({required parentSessionId}) => openedParents.add(parentSessionId),
                  onShowDiffs: () {},
                  onOpenSession: ({
                    required projectId,
                    required sessionId,
                    required sessionTitle,
                    required readOnly,
                  }) {},
                  messageImageRepository: _MockMessageImageRepository.new,
                  imageSaver: _MockImageSaver.new,
                  imageClipboard: _MockImageClipboard.new,
                  imageSharer: _MockImageSharer.new,
                  canShareImages: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("the toolbar can disable auto continuation for an unavailable harness", (tester) async {
      await pumpPage(
        tester,
        session: _session.copyWith(
          autoContinuation: const SessionAutoContinuationView(
            enabled: true,
            availability: AutoContinuationAvailability.unavailable,
            status: SessionAutoContinuationStatus.idle(),
          ),
        ),
      );
      when(() => cubit.setAutoContinuation(enabled: false)).thenAnswer((_) async {});
      await tester.tap(find.byKey(const Key("desktop-session-page-more")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key("session-auto-continuation-toggle")));
      verify(() => cubit.setAutoContinuation(enabled: false)).called(1);
    });

    testWidgets("sits above a centred transcript column", (tester) async {
      await pumpPage(tester, session: _session);

      final toolbar = tester.getRect(find.byType(DesktopPageToolbar));
      final list = tester.widget<SessionDetailMessageList>(find.byType(SessionDetailMessageList));
      expect(tester.getRect(find.byType(SessionDetailLoadedView)).top, toolbar.bottom);
      expect(list.topInset, 0);
      expect(list.horizontalInset, (1400 - DesktopSessionDetailView.maxContentWidth) / 2);
    });

    testWidgets("a long draft scrolls in place so a minimum-size window keeps the selectors", (tester) async {
      await pumpPage(tester, session: _session);
      // The desktop minimum window, seen by layout and MediaQuery alike.
      await tester.binding.setSurfaceSize(null);
      tester.view
        ..physicalSize = const Size(560, 480)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Follow up..."));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText), List.generate(30, (line) => "Line $line").join("\n"));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(TextField)).height, lessThanOrEqualTo(480 / 3));
      expect(
        tester.getRect(find.byKey(const ValueKey("sub_agents_pill"))).top,
        greaterThanOrEqualTo(tester.getRect(find.byType(SessionDetailLoadedView)).top),
      );
    });

    testWidgets("a subtask's breadcrumb leads the status slot and the bold title, and returns to its parent", (
      tester,
    ) async {
      await pumpPage(tester, session: _session);

      final breadcrumb = find.byKey(const Key("desktop-page-breadcrumb"));
      // One size with the title, quieter in weight and colour.
      final crumbText = tester.widget<Text>(find.descendant(of: breadcrumb, matching: find.text("Main session")));
      expect(crumbText.style?.fontSize, 16);
      expect(crumbText.style?.fontWeight, FontWeight.w500);
      expect(crumbText.style?.color, PregoDesignSystem.light.colors.textSecondary);
      final title = find.descendant(of: find.byType(DesktopPageToolbar), matching: find.text("Desktop session"));
      expect(tester.widget<Text>(title).style?.fontSize, 16);
      expect(tester.widget<Text>(title).style?.fontWeight, FontWeight.bold);
      // The pending question puts the awaiting glyph in the slot before the title.
      final signals = find.byType(DesktopSessionSignals);
      expect(tester.widget<DesktopSessionSignals>(signals).isAwaitingInput, isTrue);
      expect(tester.getTopLeft(breadcrumb).dx, lessThan(tester.getTopLeft(signals).dx));
      expect(tester.getTopLeft(signals).dx, lessThan(tester.getTopLeft(title).dx));

      await tester.tap(breadcrumb);
      expect(openedParents, ["parent-1"]);
      expect(openedProject, 0);
    });

    testWidgets("Mark unread from the menu shows its shortcut, sends read: false and leaves the page", (
      tester,
    ) async {
      await pumpPage(tester, session: _session);
      expect(find.byKey(const Key("desktop-session-page-mark-unread")), findsNothing);

      await tester.tap(find.byKey(const Key("desktop-session-page-more")));
      await tester.pumpAndSettle();
      expect(find.text("Ctrl+Shift+U"), findsOneWidget);
      await tester.tap(find.text("Mark as unread"));
      await tester.pumpAndSettle();

      verify(() => listCubit.markSessionSeen(sessionId: "session-1", read: false)).called(1);
      expect(markedUnread, [_session]);
      expect(leftPage, 1);
    });

    testWidgets("Shift+Ctrl+U marks the open session unread", (tester) async {
      await pumpPage(tester, session: _session);
      await tester.tap(find.text("Follow up..."));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

      verify(() => listCubit.markSessionSeen(sessionId: "session-1", read: false)).called(1);
      expect(leftPage, 1);
    });

    testWidgets("offers the session's actions with Mark as unread, never Mark as read", (tester) async {
      await pumpPage(tester, session: _session);

      await tester.tap(find.byKey(const Key("desktop-session-page-more")));
      await tester.pumpAndSettle();

      verify(() => listCubit.updateActionSession(session: _session)).called(1);
      expect(find.text("Rename"), findsOneWidget);
      expect(find.text("Archive"), findsOneWidget);
      expect(find.text("Delete"), findsOneWidget);
      expect(find.text("Mark as read"), findsNothing);
      expect(find.text("Mark as unread"), findsOneWidget);
    });
  });
}
