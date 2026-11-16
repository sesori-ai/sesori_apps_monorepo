import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/widgets/desktop_connection_pill_slot.dart";
import "package:sesori_desktop/core/widgets/desktop_page_toolbar.dart";
import "package:sesori_desktop/core/widgets/desktop_session_signals.dart";
import "package:sesori_desktop/core/widgets/desktop_transcript_width.dart";
import "package:sesori_desktop/features/sessions/desktop_session_detail_screen.dart";
import "package:sesori_desktop/features/sessions/desktop_side_chat_panel.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

class _MockSessionActionsCubit() extends MockCubit<void> implements SessionActionsCubit;

class _MockConnectionOverlayCubit() extends MockCubit<ConnectionOverlayState> implements ConnectionOverlayCubit;

class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;

class _MockLocalBridgeStartupCubit() extends MockCubit<LocalBridgeStartupState> implements LocalBridgeStartupCubit;

/// The shell's record of what covers the page's trailing edge.
RepositoryProvider<DesktopTrailingPanelCover> _panelCover() =>
    RepositoryProvider(create: (_) => DesktopTrailingPanelCover(), dispose: (cover) => cover.dispose());

/// A bridge running on this computer, as the connection pill reads it.
const _runningBridge = BridgeControlState(
  trayAvailability: SystemTrayAvailability.available,
  activity: BridgeControlActivity.idle,
  statusLabel: "Bridge status",
  statusDetail: null,
  processState: BridgeProcessRunning(pid: 42),
  desiredState: BridgeProcessDesiredState.on,
  toggleTarget: BridgeProcessDesiredState.off,
  launchAtLoginEnabled: false,
  controlStatus: BridgeControlStatus(
    startup: ControlStartupState.ready,
    helperOnline: false,
    bridgeId: null,
    relay: ControlRelayConnectionState.disconnected,
    unhealthyPlugins: [],
    activeSessionCount: 0,
  ),
  updateState: DesktopUpdateManagedBySystem(),
);

class _MockMessageImageRepository() extends Mock implements MessageImageRepository;

class _MockImageSaver() extends Mock implements ImageSaver;

class _MockImageClipboard() extends Mock implements ImageClipboard;

class _MockImageSharer() extends Mock implements ImageSharer;

class _MockComposerAttachmentDispatcher() extends Mock implements ComposerAttachmentDispatcher;

class _MockSessionRepository() extends Mock implements SessionRepository;

const _actions = SessionListActionDispatcher(
  deleteConfirmation: SessionDeleteConfirmation.sheet,
  onSessionArchived: null,
  onSessionDeleted: null,
  onSessionMarkedUnread: null,
  openSession: _openNothing,
  createSessionSearch: _searchNothing,
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
  approvalOverride: null,
  autoContinuation: null,
  branchName: null,
  id: "child-1",
  pluginId: "opencode",
  projectID: "project-1",
  directory: "/project",
  parentID: "session-1",
  title: "Child session",
  time: SessionTime(created: 1700000000000, updated: 1700000000000, archived: null),
  promptDefaults: null,
  lastUserActivityAt: null,
  scheduledTask: null,
  forkedFrom: null,
);

/// A child session: the sidebar inventory never holds one, the page does.
const _session = Session(
  approvalOverride: null,
  autoContinuation: null,
  branchName: null,
  id: "session-1",
  pluginId: "opencode",
  projectID: "project-1",
  directory: "/project",
  parentID: "parent-1",
  title: "Desktop session",
  time: SessionTime(created: 1700000000000, updated: 1700000000000, archived: null),
  promptDefaults: null,
  lastUserActivityAt: null,
  // Local state can still say unseen just after opening.
  unseen: true,
  scheduledTask: null,
  forkedFrom: null,
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
    launchHandoff: null,
    olderMessagesCursor: null,
    userMessagesBeforeOldest: null,
    promptIndex: null,
    streamingText: const {},
    sessionStatus: const SessionStatus.idle(),
    pendingQuestions: const [_question],
    pendingPermissions: const [],
    sessionTitle: "Desktop session",
    session: session,
    pluginId: "opencode",
    supportsPromptAttachments: true,
    supportsFileUploads: false,
    offersSessionMcp: true,
    sideQuestions: SideQuestionAvailability.unresolved,
    assistantAgentModel: null,
    children: const [_child],
    childStatuses: const {"child-1": SessionStatus.idle()},
    isRootSession: true,
    isArchived: false,
    queuedMessages: const [],
    bridgePromptAttachments: const {},
    localSend: const LocalSendPhase.idle(),
    availableAgents: const [],
    availableProviders: const [],
    availableCommands: const [],
    selectedAgent: "coder",
    selectedAgentModel: null,
    promptDefaults: null,
    fastMode: false,
    stagedCommand: null,
    isRefreshing: false,
    cannotContinueMessage: null,
    namesCommandInvocations: false,
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
    fileClipboard: null,
    droppedPaths: null,
    attachKind: ComposerAttachKind.files,
    child: BlocProvider<DiffSummaryCubit>(create: (_) => _StubDiffSummaryCubit(), child: child),
  );
}

class _StubDiffSummaryCubit() extends Cubit<DiffSummaryState> implements DiffSummaryCubit {
  this : super(const DiffSummaryState.counts(additions: 12, deletions: 2));

  @override
  String get sessionId => "session-1";

  @override
  Duration get refreshInterval => Duration.zero;
}

SideChatCubit _unusedSideChatCubit({
  required String sessionId,
  required String pluginId,
  required SideQuestionAvailability availability,
  required bool isArchived,
}) => throw UnimplementedError("Side chats are not under test");

const _sideChat = SideChat(
  id: "chat-1",
  exchanges: [
    SideChatExchange(
      id: "exchange-1",
      question: "Which file holds the parser?",
      answer: "The lexer file.",
      answerNotice: null,
      askedAt: 1,
      answeredAt: 2,
    ),
  ],
);

/// The composer's labelled buttons keep their tooltip's words off the semantics
/// tree, which is what `find.byTooltip` reads.
Finder _tooltip(String message) => find.byWidgetPredicate((widget) => widget is Tooltip && widget.message == message);

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
      MultiBlocProvider(
        providers: [
          BlocProvider<SessionDetailCubit>.value(value: cubit),
          _panelCover(),
        ],
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
              onOpenBridgeSettings: () {},
              projectId: "project-1",
              projectName: null,
              sessionId: "session-1",
              sessionTitle: "Desktop session",
              sessionActions: _actions,
              onMarkedUnread: () {},
              readOnly: false,
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
              sessionRepository: _MockSessionRepository.new,
              createPendingFormCubit: ({required requestId, required sessionId}) =>
                  throw StateError("Unused fixture form"),
              createFilePreviewCubit: ({required reference}) =>
                  throw UnimplementedError("File previews are not under test"),
              createExternalActionCubit: ({required requestId, required sessionId}) =>
                  throw UnimplementedError("External actions are not under test"),
              createSideChatCubit: _unusedSideChatCubit,
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
    expect(
      find.descendant(of: find.byType(SessionDetailLoadedView), matching: find.byType(SessionDetailComposerControls)),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel("Start recording"), findsNothing);
    expect(messageImageRepositoryResolutions, 0);
    expect(imageSaverResolutions, 0);
    expect(imageClipboardResolutions, 0);
    expect(imageSharerResolutions, 0);

    final changes = find.byKey(const Key("desktop-session-page-changes"));
    expect(find.descendant(of: changes, matching: find.text("+12")), findsOneWidget);
    expect(find.descendant(of: changes, matching: find.text("−2")), findsOneWidget);
    await tester.tap(find.byIcon(TablerRegular.git_compare));
    expect(diffCalls, 1);

    await tester.tap(find.text("Follow up..."));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), "Desktop follow-up");
    await tester.pump();
    await tester.tap(find.byIcon(TablerRegular.arrow_up).last);
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
    expect(_tooltip("Attach files"), findsOneWidget);
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
      MultiBlocProvider(
        providers: [
          BlocProvider<SessionDetailCubit>.value(value: cubit),
          _panelCover(),
        ],
        // The desktop shell always runs under a pointer scope.
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
                onOpenBridgeSettings: () {},
                projectId: "project-1",
                projectName: null,
                sessionId: "session-1",
                sessionTitle: "Desktop session",
                sessionActions: _actions,
                onMarkedUnread: () {},
                readOnly: false,
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
                sessionRepository: _MockSessionRepository.new,
                createPendingFormCubit: ({required requestId, required sessionId}) =>
                    throw StateError("Unused fixture form"),
                createFilePreviewCubit: ({required reference}) =>
                    throw UnimplementedError("File previews are not under test"),
                createExternalActionCubit: ({required requestId, required sessionId}) =>
                    throw UnimplementedError("External actions are not under test"),
                createSideChatCubit: _unusedSideChatCubit,
                canShareImages: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The finished sub-agent folds into its group's summary.
    await tester.tap(find.text("1 step"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Explore Child session"));
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
    late _MockSessionActionsCubit actions;
    late List<Session> markedUnread;
    late int leftPage;
    late List<String> openedParents;
    late MockSideChatRepository sideChats;
    late List<SideChatCubit> createdSideChats;
    late _MockConnectionOverlayCubit overlay;

    /// Another session page, as a subtask pushed over the one under test.
    late Widget Function() pushablePage;

    Future<void> pumpPage(
      WidgetTester tester, {
      required Session session,
      bool readOnly = false,
      SessionPromptDefaults? promptDefaults,
      SessionDetailState? initialState,
      Stream<SessionDetailState> states = const Stream.empty(),
      Brightness brightness = Brightness.light,
      Key? pageKey,
      ConnectionOverlayState connection = const ConnectionOverlayState.hidden(connected: true),
    }) async {
      cubit = _MockSessionDetailCubit();
      when(() => cubit.isRouteVisible).thenReturn(true);
      final state = initialState ?? _loadedState(session: session).copyWith(promptDefaults: promptDefaults);
      when(() => cubit.state).thenReturn(state);
      whenListen(cubit, states, initialState: state);
      when(() => cubit.questionStream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.permissionStream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.noticeStream).thenAnswer((_) => const Stream.empty());
      when(cubit.clearNotifications).thenReturn(null);
      when(() => cubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
      actions = _MockSessionActionsCubit();
      when(
        () => actions.markSessionSeen(
          projectId: any(named: "projectId"),
          sessionId: any(named: "sessionId"),
          read: any(named: "read"),
        ),
      ).thenAnswer((_) async {});
      markedUnread = [];
      leftPage = 0;
      openedParents = [];
      sideChats = MockSideChatRepository();
      when(
        () => sideChats.listSideChats(sessionId: any(named: "sessionId")),
      ).thenAnswer((_) async => ApiResponse.success(const SideChatListResponse(sideChats: [_sideChat])));
      createdSideChats = [];
      overlay = _MockConnectionOverlayCubit();
      whenListen(overlay, const Stream<ConnectionOverlayState>.empty(), initialState: connection);
      final bridge = _MockBridgeControlCubit();
      whenListen(bridge, const Stream<BridgeControlState>.empty(), initialState: _runningBridge);
      final startup = _MockLocalBridgeStartupCubit();
      whenListen(
        startup,
        const Stream<LocalBridgeStartupState>.empty(),
        initialState: LocalBridgeStartupState.settled,
      );
      Widget page({required Key? key}) => _composerScope(
        imageClipboard: _MockImageClipboard.new,
        child: DesktopSessionDetailView(
          key: key,
          onOpenHarnessSettings: () {},
          onOpenBridgeSettings: () {},
          projectId: "project-1",
          projectName: null,
          sessionId: "session-1",
          sessionTitle: "Desktop session",
          sessionActions: SessionListActionDispatcher(
            deleteConfirmation: SessionDeleteConfirmation.sheet,
            onSessionArchived: null,
            onSessionDeleted: null,
            onSessionMarkedUnread: ({required context, required session}) => markedUnread.add(session),
            openSession: _openNothing,
            createSessionSearch: _searchNothing,
          ),
          onMarkedUnread: () => leftPage++,
          readOnly: readOnly,
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
          sessionRepository: _MockSessionRepository.new,
          createPendingFormCubit: ({required requestId, required sessionId}) => throw StateError("Unused fixture form"),
          createFilePreviewCubit: ({required reference}) =>
              throw UnimplementedError("File previews are not under test"),
          createExternalActionCubit: ({required requestId, required sessionId}) =>
              throw UnimplementedError("External actions are not under test"),
          createSideChatCubit: ({required sessionId, required pluginId, required availability, required isArchived}) {
            final sideChat = SideChatCubit(
              repository: sideChats,
              productAnalyticsService: MockProductAnalyticsService(),
              sessionId: sessionId,
              pluginId: pluginId,
              availability: availability,
              isArchived: isArchived,
              initialQuestion: null,
            );
            createdSideChats.add(sideChat);
            return sideChat;
          },
          canShareImages: true,
        ),
      );
      pushablePage = () => page(key: null);
      await tester.binding.setSurfaceSize(const Size(1400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<SessionDetailCubit>.value(value: cubit),
            BlocProvider<SessionActionsCubit>.value(value: actions),
            // The shell's connection pill, over the page as in the cockpit.
            BlocProvider<ConnectionOverlayCubit>.value(value: overlay),
            BlocProvider<BridgeControlCubit>.value(value: bridge),
            BlocProvider<LocalBridgeStartupCubit>.value(value: startup),
            _panelCover(),
          ],
          // The desktop is a pointer surface: its menus draw shortcut labels.
          child: PregoInteractionScope(
            mode: PregoInteractionMode.pointer,
            child: MaterialApp(
              theme: ThemeData(
                extensions: [if (brightness == Brightness.light) PregoDesignSystem.light else PregoDesignSystem.dark],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              // The shell's pill floats over every page, as the cockpit's does.
              builder: (context, child) => Stack(
                fit: StackFit.expand,
                children: [
                  ?child,
                  const Positioned.fill(child: DesktopConnectionPillSlot()),
                ],
              ),
              home: page(key: pageKey),
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

    testWidgets("a read-only child names what it ran with in pills that hug their labels", (tester) async {
      await pumpPage(
        tester,
        session: _session,
        readOnly: true,
        promptDefaults: const SessionPromptDefaults(
          agent: null,
          model: AgentModel(providerID: "anthropic", modelID: "claude-sonnet-4-5", variant: "high"),
        ),
      );

      expect(find.byType(SessionDetailComposerControls), findsNothing);
      final pills = find.descendant(of: find.byType(ReadOnlyAgentModelPills), matching: find.byType(PregoPickerButton));
      expect(pills, findsNWidgets(2));
      // Without a catalog entry the model shows its id.
      expect(find.descendant(of: pills.first, matching: find.text("claude-sonnet-4-5")), findsOneWidget);
      expect(find.descendant(of: pills.last, matching: find.text("high")), findsOneWidget);
      expect(tester.getSize(pills.last).width, lessThan(tester.getSize(pills.first).width));
      expect(find.descendant(of: find.byType(ReadOnlyAgentModelPills), matching: find.byType(InkWell)), findsNothing);
    });

    testWidgets("sits above a transcript column centred wider than its own", (tester) async {
      await pumpPage(tester, session: _session);

      final toolbar = tester.getRect(find.byType(DesktopPageToolbar));
      final list = tester.widget<SessionDetailMessageList>(find.byType(SessionDetailMessageList));
      expect(tester.getRect(find.byType(SessionDetailLoadedView)).top, toolbar.bottom);
      // A pinned prompt pushed out over the transcript's top edge slides under
      // the toolbar rather than painting over it.
      final clip = find.ancestor(of: find.byType(SessionDetailLoadedView), matching: find.byType(ClipRect)).first;
      expect(tester.getRect(clip).top, toolbar.bottom);
      expect(list.topInset, 0);
      // The transcript reads in its own, wider column; the composer keeps the
      // narrower one, both centred in the same pane.
      expect(list.horizontalInset, (1400 - desktopTranscriptWidth) / 2);
      expect(
        tester.getSize(find.byType(SessionDetailComposerControls)).width,
        desktopComposerWidth,
      );
      expect(desktopTranscriptWidth, greaterThan(desktopComposerWidth));
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
    });

    // The waiting amber, as on every waiting dot.
    for (final (brightness, amber) in [
      (Brightness.light, const Color(0xFFD98200)),
      (Brightness.dark, const Color(0xFFF79009)),
    ]) {
      testWidgets("the waiting dot before the title is the waiting amber in ${brightness.name}", (tester) async {
        await pumpPage(tester, session: _session, brightness: brightness);

        final signals = find.byType(DesktopSessionSignals);
        expect(tester.widget<DesktopSessionSignals>(signals).isAwaitingInput, isTrue);
        expect(
          tester.widget<Container>(find.descendant(of: signals, matching: find.byType(Container))).decoration,
          isA<BoxDecoration>().having((decoration) => decoration.color, "color", amber),
        );
      });
    }

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

      verify(
        () => actions.markSessionSeen(
          projectId: any(named: "projectId"),
          sessionId: "session-1",
          read: false,
        ),
      ).called(1);
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

      verify(
        () => actions.markSessionSeen(
          projectId: any(named: "projectId"),
          sessionId: "session-1",
          read: false,
        ),
      ).called(1);
      expect(leftPage, 1);
    });

    testWidgets("the Prompts button sits before More and opens the Prompts screen over the page", (tester) async {
      when(() => cubit.reportPromptsOpened(entry: AnalyticsPromptsEntry.sessionBar)).thenReturn(null);
      await pumpPage(tester, session: _session);
      final prompts = find.byKey(const Key("desktop-session-page-prompts"));
      expect(
        tester.getCenter(prompts).dx,
        lessThan(tester.getCenter(find.byKey(const Key("desktop-session-page-more"))).dx),
      );
      expect(tester.widget<IconButton>(prompts).tooltip, "Prompts");

      await tester.tap(prompts);
      await tester.pumpAndSettle();
      verify(() => cubit.reportPromptsOpened(entry: AnalyticsPromptsEntry.sessionBar)).called(1);
      expect(find.byTooltip("Close prompts"), findsOneWidget);

      await tester.tap(find.byTooltip("Close prompts"));
      await tester.pumpAndSettle();
      expect(find.byTooltip("Close prompts"), findsNothing);
    });

    testWidgets("Changes and Prompts fade in with the transcript and out when it leaves", (tester) async {
      const frame = Duration(milliseconds: 16);
      const notice = SessionDetailState.harnessUnavailable(
        session: _session,
        interaction: SessionInteractionState.blocked(
          reason: SessionInteractionBlockedReason.authenticationRequired,
          displayName: "Claude Code",
          actionHint: null,
          refreshError: null,
        ),
      );
      final loaded = _loadedState(session: _session);
      final states = StreamController<SessionDetailState>();
      addTearDown(states.close);
      await pumpPage(tester, session: _session, initialState: notice, states: states.stream);
      final changes = find.byKey(const Key("desktop-session-page-changes"));
      final prompts = find.byKey(const Key("desktop-session-page-prompts"));
      double opacityOf(Finder finder) => tester
          .widgetList<FadeTransition>(find.ancestor(of: finder, matching: find.byType(FadeTransition)))
          .fold(1, (opacity, fade) => opacity * fade.opacity.value);
      expect(changes, findsNothing);
      expect(prompts, findsNothing);

      Future<void> expectFade({required SessionDetailState to, required bool arriving}) async {
        states.add(to);
        final seen = <double>[];
        for (var elapsed = Duration.zero; elapsed <= const Duration(milliseconds: 320); elapsed += frame) {
          await tester.pump(frame);
          if (changes.evaluate().isEmpty) break;
          // The two move as one, neither popping in or out.
          expect(opacityOf(prompts), opacityOf(changes));
          seen.add(opacityOf(changes));
          if (!arriving) {
            // Leaving, they no longer act on the transcript they leave.
            expect(changes.hitTestable(), findsNothing);
            expect(prompts.hitTestable(), findsNothing);
            expect(find.semantics.byLabel(RegExp("Changes")), findsNothing);
          }
        }
        expect(find.semantics.byLabel(RegExp("Changes")), arriving ? findsOneWidget : findsNothing);
        expect(changes, arriving ? findsOneWidget : findsNothing);
        expect(prompts, arriving ? findsOneWidget : findsNothing);
        expect(seen.where((opacity) => opacity > 0 && opacity < 1), hasLength(greaterThanOrEqualTo(10)));
        for (var i = 1; i < seen.length; i++) {
          expect(seen[i], arriving ? greaterThanOrEqualTo(seen[i - 1]) : lessThanOrEqualTo(seen[i - 1]));
        }
      }

      await expectFade(to: loaded, arriving: true);
      await expectFade(to: notice, arriving: false);
      // A reload from the transcript passes through loading, which has none.
      await expectFade(to: loaded, arriving: true);
      await expectFade(
        to: const SessionDetailState.loading(launchHandoff: null, seededComposer: null),
        arriving: false,
      );
      await expectFade(to: loaded, arriving: true);
      await expectFade(to: const SessionDetailState.failed(reason: RemoteFailureReason.unknown), arriving: false);
      expect(tester.takeException(), isNull);
    });

    testWidgets("absent Changes and Prompts leave the title its room", (tester) async {
      await pumpPage(
        tester,
        session: _session,
        initialState: const SessionDetailState.harnessUnavailable(
          session: _session,
          interaction: SessionInteractionState.blocked(
            reason: SessionInteractionBlockedReason.authenticationRequired,
            displayName: "Claude Code",
            actionHint: null,
            refreshError: null,
          ),
        ),
      );
      final title = find.descendant(of: find.byType(DesktopPageToolbar), matching: find.byType(Expanded)).first;
      final more = find.byKey(const Key("desktop-session-page-more"));
      expect(tester.getRect(more).left - tester.getRect(title).right, PregoSpacing.md);
    });

    testWidgets(
      "Shift+Cmd/Ctrl+U marks the session unread before the composer is focused",
      (tester) async {
        await pumpPage(tester, session: _session);
        // The page holds focus for its shortcuts but is no Tab stop.
        expect(FocusManager.instance.primaryFocus?.skipTraversal, isTrue);
        final modifier = defaultTargetPlatform == TargetPlatform.macOS
            ? LogicalKeyboardKey.metaLeft
            : LogicalKeyboardKey.controlLeft;
        Future<void> markUnread() async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyDownEvent(modifier);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
          await tester.sendKeyUpEvent(modifier);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        }

        await markUnread();
        verify(
          () => actions.markSessionSeen(
            projectId: any(named: "projectId"),
            sessionId: "session-1",
            read: false,
          ),
        ).called(1);

        // Focus that left the page, as to the sidebar, returns with a click in it.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        await markUnread();
        verifyNever(
          () => actions.markSessionSeen(
            projectId: any(named: "projectId"),
            sessionId: "session-1",
            read: false,
          ),
        );
        await tester.tapAt(tester.getCenter(find.byType(Scaffold).last));
        await tester.pump();
        await markUnread();
        verify(
          () => actions.markSessionSeen(
            projectId: any(named: "projectId"),
            sessionId: "session-1",
            read: false,
          ),
        ).called(1);
      },
      variant: const TargetPlatformVariant({TargetPlatform.macOS, TargetPlatform.linux}),
    );

    testWidgets("offers MCP in the menu", (tester) async {
      await pumpPage(tester, session: _session);
      await tester.tap(find.byKey(const Key("desktop-session-page-more")));
      await tester.pumpAndSettle();

      expect(find.text("MCP"), findsOneWidget);
    });

    testWidgets("leaves MCP out of the menu for a harness that answers no MCP for a session", (tester) async {
      await pumpPage(
        tester,
        session: _session,
        initialState: _loadedState(session: _session).copyWith(offersSessionMcp: false),
      );
      await tester.tap(find.byKey(const Key("desktop-session-page-more")));
      await tester.pumpAndSettle();
      expect(find.text("MCP"), findsNothing);
      expect(find.text("Mark as unread"), findsOneWidget);
    });

    testWidgets("offers the session's actions with Mark as unread, never Mark as read", (tester) async {
      await pumpPage(tester, session: _session);

      await tester.tap(find.byKey(const Key("desktop-session-page-more")));
      await tester.pumpAndSettle();

      expect(find.text("Rename"), findsOneWidget);
      expect(find.text("Archive"), findsOneWidget);
      expect(find.text("Delete"), findsOneWidget);
      expect(find.text("Mark as read"), findsNothing);
      expect(find.text("Mark as unread"), findsOneWidget);
    });

    group("side chats", () {
      final root = _session.copyWith(parentID: null);
      final panel = find.byKey(DesktopSideChatPanelHost.panelKey);
      Rect transcript(WidgetTester tester) => tester.getRect(find.text("Desktop transcript"));

      SessionDetailLoaded sideChatState({bool archived = false}) => _loadedState(session: root).copyWith(
        sideQuestions: SideQuestionAvailability.available,
        pendingQuestions: const [],
        isArchived: archived,
        archivedSideChatCount: archived ? 1 : 0,
      );

      // The panel's field takes the focus, and its blinking caret never lets
      // the frames settle, so these tests pump past the slide instead.
      Future<void> openFromComposer(WidgetTester tester) async {
        await tester.tap(find.byKey(ComposerOptionsAccordion.sideQuestionButtonKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      testWidgets("the composer's button slides the panel in over the page, leaving the transcript in place", (
        tester,
      ) async {
        await pumpPage(tester, session: root, initialState: sideChatState());
        final before = transcript(tester);
        expect(panel, findsNothing);

        await tester.tap(find.byKey(ComposerOptionsAccordion.sideQuestionButtonKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        // Midway it is still partly past the window's edge, and the
        // transcript has neither moved nor been laid out again.
        expect(tester.getRect(panel).right, greaterThan(1400));
        expect(transcript(tester), before);

        await tester.pump(const Duration(milliseconds: 220));
        final rect = tester.getRect(panel);
        expect(rect.width, DesktopSideChatPanelHost.width);
        expect(rect.top, DesktopPageToolbar.height);
        expect(rect.right, 1400 - PregoSpacing.lg);
        expect(rect.bottom, 800 - PregoSpacing.lg);
        expect(transcript(tester), before);
        expect(find.descendant(of: panel, matching: find.text("Side question")), findsOneWidget);
        final field = tester.widget<EditableText>(
          find.descendant(of: find.byKey(SideChatView.questionFieldKey), matching: find.byType(EditableText)),
        );
        expect(field.focusNode.hasFocus, isTrue);

        // The page behind keeps taking clicks.
        await tester.tap(find.byKey(const Key("desktop-session-page-more")));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text("Mark as unread"), findsOneWidget);
      });

      testWidgets("the close button slides the panel away, and its chat ends once it has gone", (tester) async {
        await pumpPage(tester, session: root, initialState: sideChatState());
        await openFromComposer(tester);

        await tester.tap(find.descendant(of: panel, matching: find.byIcon(TablerRegular.x)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getRect(panel).right, greaterThan(1400 - PregoSpacing.lg));
        expect(createdSideChats.single.isClosed, isFalse);
        final leaving = find.ancestor(of: panel, matching: find.byType(IgnorePointer)).first;
        expect(tester.widget<IgnorePointer>(leaving).ignoring, isTrue, reason: "a leaving panel takes no clicks");

        await tester.pump(const Duration(milliseconds: 200));
        expect(panel, findsNothing);
        expect(createdSideChats.single.isClosed, isTrue);
      });

      testWidgets("with the connection lost, the pill moves aside with the panel and both keep their clicks", (
        tester,
      ) async {
        await pumpPage(
          tester,
          session: root,
          initialState: sideChatState(),
          connection: const ConnectionOverlayState.connectionLost(),
        );
        final pill = find.byKey(const Key("desktop-connection-pill"));
        final resting = tester.getRect(pill);
        expect(resting.right, 1400 - PregoSpacing.xl);

        await tester.tap(find.byKey(ComposerOptionsAccordion.sideQuestionButtonKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        // It moves with the panel, never under it.
        expect(tester.getRect(pill).right, lessThan(resting.right));
        expect(tester.getRect(pill).right, lessThan(tester.getRect(panel).left));

        await tester.pump(const Duration(milliseconds: 220));
        expect(tester.getRect(pill).right, tester.getRect(panel).left - PregoSpacing.xl);
        expect(tester.getRect(pill).top, resting.top);
        await tester.tap(find.text("Reconnect"));
        verify(overlay.reconnect).called(1);

        await tester.tap(find.descendant(of: panel, matching: find.byIcon(TablerRegular.x)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getRect(pill).right, lessThan(tester.getRect(panel).left));
        await tester.pump(const Duration(milliseconds: 200));
        expect(panel, findsNothing, reason: "the close button took the click");
        expect(tester.getRect(pill), resting);
      });

      testWidgets("in the narrowest window the pill heads for the middle, over the panel's top, to stay in view", (
        tester,
      ) async {
        await pumpPage(
          tester,
          session: root,
          initialState: sideChatState(),
          connection: const ConnectionOverlayState.connectionLost(),
        );
        await tester.binding.setSurfaceSize(const Size(560, 800));
        await tester.pump();
        final pill = find.byKey(const Key("desktop-connection-pill"));
        final resting = tester.getRect(pill);
        expect(resting.right, 560 - PregoSpacing.xl);

        await tester.tap(find.byKey(ComposerOptionsAccordion.sideQuestionButtonKey));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        // On its way it moves with the panel rather than jumping.
        final moving = tester.getRect(pill);
        expect(moving.left, lessThan(resting.left));
        expect(moving.center.dx, greaterThan(280));

        await tester.pump(const Duration(milliseconds: 220));
        final settled = tester.getRect(pill);
        expect(settled.center.dx, moreOrLessEquals(280));
        expect(settled.left, greaterThanOrEqualTo(0));
        expect(settled.right, lessThanOrEqualTo(560));
        await tester.tap(find.text("Reconnect"));
        verify(overlay.reconnect).called(1);

        // The panel's close button stays clear of it.
        await tester.tap(find.descendant(of: panel, matching: find.byIcon(TablerRegular.x)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(panel, findsNothing);
        expect(tester.getRect(pill), resting);
      });

      testWidgets("a subtask pushed over the open panel takes the pill back, and returning hands it over again", (
        tester,
      ) async {
        await pumpPage(
          tester,
          session: root,
          initialState: sideChatState(),
          connection: const ConnectionOverlayState.connectionLost(),
        );
        final pill = find.byKey(const Key("desktop-connection-pill"));
        final resting = tester.getRect(pill);
        await openFromComposer(tester);
        final aside = tester.getRect(pill);
        expect(aside.right, lessThan(resting.right));

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(MaterialPageRoute<void>(builder: (_) => pushablePage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.getRect(pill), resting, reason: "the subtask shows no panel");

        navigator.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(panel, findsOneWidget);
        expect(tester.getRect(pill), aside, reason: "the leaving subtask keeps the parent's cover");
        await tester.tap(find.descendant(of: panel, matching: find.byIcon(TablerRegular.x)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(panel, findsNothing);
      });

      testWidgets("Escape closes the panel at once, from its field or from the page's composer", (tester) async {
        await pumpPage(tester, session: root, initialState: sideChatState());
        final before = transcript(tester);
        await openFromComposer(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(panel, findsNothing);
        expect(transcript(tester), before);

        await openFromComposer(tester);
        final composerField = tester.widget<EditableText>(
          find.descendant(of: find.byType(SessionDetailComposerControls), matching: find.byType(EditableText)),
        );
        composerField.focusNode.requestFocus();
        await tester.pump();
        expect(composerField.focusNode.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(panel, findsNothing);
        // The composer keeps its focus: Escape went to the panel alone.
        expect(composerField.focusNode.hasFocus, isTrue);
        expect(createdSideChats, hasLength(2));
      });

      testWidgets("switching sessions closes the panel", (tester) async {
        await pumpPage(tester, session: root, initialState: sideChatState(), pageKey: const ValueKey("session-1"));
        await openFromComposer(tester);
        expect(panel, findsOneWidget);

        await pumpPage(
          tester,
          session: root.copyWith(id: "session-2"),
          initialState: sideChatState(),
          pageKey: const ValueKey("session-2"),
        );
        expect(panel, findsNothing);
      });

      testWidgets("an archived session's Side chats link opens its newest chat read-only in the panel", (
        tester,
      ) async {
        await pumpPage(tester, session: root, initialState: sideChatState(archived: true));

        await tester.tap(find.text("Side chats (1)"));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: panel, matching: find.text("This session is archived. Its side chats are read-only.")),
          findsOneWidget,
        );
        expect(find.descendant(of: panel, matching: find.byKey(SideChatView.questionFieldKey)), findsNothing);
        expect(createdSideChats.single.canAsk, isFalse);

        // With no field to hold it, the panel keeps the focus for Escape.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(panel, findsNothing);
      });
    });
  });
}

void _openNothing({required String projectId, required String projectName, required Session session}) {}

SessionSearchCubit _searchNothing({
  required SessionWindowService window,
  required ProjectInventoryService projectInventory,
  required String? excludedSessionId,
}) => throw UnimplementedError("These tests do not send sessions");
