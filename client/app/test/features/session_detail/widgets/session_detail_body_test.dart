import "dart:async";
import "dart:ui" show PointerDeviceKind;

import "package:bloc_test/bloc_test.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart" show kSecondaryButton;
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/session_detail/widgets/prompt_editor_sheet.dart";
import "package:sesori_mobile/features/session_detail/widgets/session_detail_body.dart";
import "package:sesori_mobile/features/session_detail/widgets/voice_cancel_button.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/test_helpers.dart";

class MockSessionDetailCubit extends MockCubit<SessionDetailState> implements SessionDetailCubit {}

class MockVoiceTranscriptionService extends Mock implements VoiceTranscriptionService {}

Widget _buildApp({
  required SessionDetailCubit cubit,
  ChatInputMode chatInputMode = ChatInputMode.voiceFirst,
  StubChatInputModeCubit? chatInputModeCubit,
  bool startAtPreviousScreen = false,
}) {
  final router = GoRouter(
    initialLocation: startAtPreviousScreen ? "/previous" : "/",
    routes: [
      GoRoute(
        path: "/previous",
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push("/"),
              child: const Text("Open session"),
            ),
          ),
        ),
      ),
      GoRoute(
        path: "/",
        builder: (context, state) => BlocProvider<SessionDetailCubit>.value(
          value: cubit,
          child: const SessionDetailBody(
            projectId: "project-1",
            projectName: null,
            sessionId: "session-1",
            sessionTitle: "Session",
            readOnly: false,
          ),
        ),
      ),
      GoRoute(
        path: "/projects/:projectId/sessions/:sessionId/diffs",
        builder: (context, state) => const Scaffold(body: Text("Diffs")),
      ),
    ],
  );

  return MultiBlocProvider(
    providers: [
      BlocProvider<ConnectionOverlayCubit>(create: (_) => StubConnectionOverlayCubit()),
      BlocProvider<ChatInputModeCubit>(
        create: (_) => chatInputModeCubit ?? StubChatInputModeCubit(initialState: chatInputMode),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

SessionDetailLoaded _loadedState({
  required List<SesoriQuestionAsked> pendingQuestions,
  required List<SesoriPermissionAsked> pendingPermissions,
  List<MessageWithParts> messages = const [],
  SessionStatus sessionStatus = const SessionStatus.idle(),
}) {
  final provider = testProviderListResponse().items.first;
  return SessionDetailLoaded(
    messages: messages,
    streamingText: const {},
    sessionStatus: sessionStatus,
    pendingQuestions: pendingQuestions,
    pendingPermissions: pendingPermissions,
    sessionTitle: "Session",
    agent: null,
    assistantAgentModel: null,
    children: const [],
    childStatuses: const {},
    isRootSession: true,
    isArchived: false,
    queuedMessages: const [],
    availableAgents: [testAgentInfo()],
    availableProviders: [provider],
    availableCommands: const [],
    selectedAgent: "coder",
    selectedAgentModel: AgentModel(
      providerID: provider.id,
      modelID: provider.defaultModelID!,
      variant: "xhigh",
    ),
    stagedCommand: null,
    isRefreshing: false,
    availableVariants: const [SessionVariant(id: "xhigh")],
    retryErrorMessage: null,
  );
}

const _question = SesoriQuestionAsked(
  id: "question-1",
  sessionID: "session-1",
  displaySessionId: null,
  questions: [
    QuestionInfo(
      question: "Choose a release channel",
      header: "Release channel",
      options: [QuestionOption(label: "Stable", description: "Release to everyone")],
    ),
  ],
);

const _permission = SesoriPermissionAsked(
  requestID: "permission-1",
  sessionID: "session-1",
  displaySessionId: null,
  tool: "write_release_notes",
  description: "Allow writing the release notes",
);

void main() {
  late MockSessionDetailCubit cubit;
  late MockVoiceTranscriptionService voiceTranscriptionService;

  setUpAll(() {
    registerFallbackValue(ComposerDraft.typed(text: ""));
  });

  // flutter_test defaults `defaultTargetPlatform` to android, so PregoAnchorMenu
  // renders its flat (cue) menu here — the menu rows are Material InkWells, not
  // GlassMenuItems. Finders below target those InkWells.
  setUp(() async {
    KeyboardVisibilityTesting.setVisibilityForTesting(false);
    await GetIt.instance.reset();
    cubit = MockSessionDetailCubit();
    voiceTranscriptionService = MockVoiceTranscriptionService();

    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []);
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);
    when(() => cubit.questionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.permissionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
    when(
      () => cubit.saveComposerDraft(draft: any(named: "draft")),
    ).thenReturn(null);
    when(cubit.clearComposerDraft).thenReturn(null);
    when(cubit.reportVoiceTranscriptionCompleted).thenReturn(null);

    final maxDurationReached = StreamController<void>.broadcast();
    addTearDown(maxDurationReached.close);
    when(() => voiceTranscriptionService.onMaxDurationReached).thenAnswer((_) => maxDurationReached.stream);

    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets("opens the variant picker and forwards the selection to the cubit", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Regression guard: the loaded state here has a null agent and model, so
    // the bar subtitle must collapse to empty — never a literal "null".
    expect(find.text("null"), findsNothing);

    await tester.tap(find.widgetWithText(GlassButton, "xhigh"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InkWell, "xhigh"), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, "xhigh"));
    await tester.pumpAndSettle();

    verify(() => cubit.selectVariant(const SessionVariant(id: "xhigh"))).called(1);
  });

  testWidgets("selecting a different variant updates the displayed variant", (tester) async {
    final initialState = _loadedState(pendingQuestions: const [], pendingPermissions: const []);
    final updatedState = SessionDetailState.loaded(
      messages: const [],
      streamingText: const {},
      sessionStatus: const SessionStatus.idle(),
      pendingQuestions: const [],
      pendingPermissions: const [],
      sessionTitle: "Session",
      agent: null,
      assistantAgentModel: null,
      children: const [],
      childStatuses: const {},
      isRootSession: true,
      isArchived: false,
      queuedMessages: const [],
      availableAgents: [testAgentInfo()],
      availableProviders: testProviderListResponse().items,
      availableCommands: const [],
      selectedAgent: "coder",
      selectedAgentModel: const AgentModel(
        providerID: "anthropic",
        modelID: "claude-3-5-sonnet",
        variant: null,
      ),
      stagedCommand: null,
      isRefreshing: false,
      availableVariants: const [SessionVariant(id: "xhigh")],
      retryErrorMessage: null,
    );

    final controller = StreamController<SessionDetailState>.broadcast();
    addTearDown(controller.close);
    when(() => cubit.state).thenReturn(initialState);
    when(() => cubit.stream).thenAnswer((_) => controller.stream);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Initially shows the selected variant.
    expect(find.widgetWithText(GlassButton, "xhigh"), findsOneWidget);

    // Open variant picker.
    await tester.tap(find.widgetWithText(GlassButton, "xhigh"));
    await tester.pumpAndSettle();

    // Select Default (null variant).
    await tester.tap(find.widgetWithText(InkWell, "Default"));
    await tester.pumpAndSettle();

    verify(() => cubit.selectVariant(null)).called(1);

    // Emit the updated state to simulate the cubit update.
    when(() => cubit.state).thenReturn(updatedState);
    controller.add(updatedState);
    await tester.pumpAndSettle();

    // The UI should now show "Default".
    expect(find.widgetWithText(GlassButton, "Default"), findsOneWidget);
    expect(find.widgetWithText(GlassButton, "xhigh"), findsNothing);
  });

  testWidgets("diff button navigates to diffs with the typed route", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.git_compare));
    await tester.pumpAndSettle();

    expect(find.text("Diffs"), findsOneWidget);
  });

  testWidgets("hides the diff button for archived sessions", (tester) async {
    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
    ).copyWith(isArchived: true);
    when(() => cubit.state).thenReturn(state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.byIcon(TablerRegular.git_compare), findsNothing);
  });

  testWidgets("closes an open question when it leaves pending state", (tester) async {
    final questions = StreamController<SesoriQuestionAsked>.broadcast();
    final states = StreamController<SessionDetailState>.broadcast();
    addTearDown(questions.close);
    addTearDown(states.close);
    var state = _loadedState(pendingQuestions: const [], pendingPermissions: const []);
    when(() => cubit.state).thenAnswer((_) => state);
    when(() => cubit.stream).thenAnswer((_) => states.stream);
    when(() => cubit.questionStream).thenAnswer((_) => questions.stream);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    state = state.copyWith(pendingQuestions: const [_question]);
    questions.add(_question);
    await tester.pumpAndSettle();
    expect(find.text("Choose a release channel"), findsOneWidget);

    state = state.copyWith(pendingQuestions: const []);
    states.add(state);
    await tester.pumpAndSettle();
    expect(find.text("Choose a release channel"), findsNothing);
  });

  testWidgets("does not leave a question stale when resolved during presentation", (tester) async {
    final questions = StreamController<SesoriQuestionAsked>.broadcast();
    addTearDown(questions.close);
    var state = _loadedState(pendingQuestions: const [], pendingPermissions: const []);
    when(() => cubit.state).thenAnswer((_) => state);
    when(() => cubit.questionStream).thenAnswer((_) => questions.stream);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    state = state.copyWith(pendingQuestions: const [_question]);
    questions.add(_question);
    await tester.idle();
    state = state.copyWith(pendingQuestions: const []);
    await tester.pumpAndSettle();

    expect(find.text("Choose a release channel"), findsNothing);
  });

  testWidgets("closes an open permission when it leaves pending state", (tester) async {
    final permissions = StreamController<SesoriPermissionAsked>.broadcast();
    final states = StreamController<SessionDetailState>.broadcast();
    addTearDown(permissions.close);
    addTearDown(states.close);
    var state = _loadedState(pendingQuestions: const [], pendingPermissions: const []);
    when(() => cubit.state).thenAnswer((_) => state);
    when(() => cubit.stream).thenAnswer((_) => states.stream);
    when(() => cubit.permissionStream).thenAnswer((_) => permissions.stream);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    state = state.copyWith(pendingPermissions: const [_permission]);
    permissions.add(_permission);
    await tester.pumpAndSettle();
    expect(find.text("write_release_notes"), findsOneWidget);

    state = state.copyWith(pendingPermissions: const []);
    states.add(state);
    await tester.pump();
    await tester.tap(find.text("Once"), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text("write_release_notes"), findsNothing);
    verifyNever(
      () => cubit.replyToPermission(
        requestId: "permission-1",
        sessionId: "session-1",
        reply: PermissionReply.once,
      ),
    );
  });

  testWidgets("presents a queued permission after answering an active question", (tester) async {
    final questionController = StreamController<SesoriQuestionAsked>.broadcast();
    final permissionController = StreamController<SesoriPermissionAsked>.broadcast();
    addTearDown(questionController.close);
    addTearDown(permissionController.close);
    var state = _loadedState(pendingQuestions: const [], pendingPermissions: const []);
    when(() => cubit.state).thenAnswer((_) => state);
    when(() => cubit.questionStream).thenAnswer((_) => questionController.stream);
    when(() => cubit.permissionStream).thenAnswer((_) => permissionController.stream);
    when(
      () => cubit.replyToQuestion(
        requestId: "question-1",
        sessionId: "session-1",
        answers: any(named: "answers"),
      ),
    ).thenAnswer((_) async {
      state = state.copyWith(pendingQuestions: const []);
      return true;
    });

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    state = state.copyWith(pendingQuestions: const [_question]);
    questionController.add(_question);
    await tester.pumpAndSettle();
    expect(find.text("Choose a release channel"), findsOneWidget);

    state = state.copyWith(pendingPermissions: const [_permission]);
    permissionController.add(_permission);
    await tester.pumpAndSettle();
    expect(find.text("write_release_notes"), findsNothing);

    await tester.tap(find.text("Stable"));
    await tester.pump();
    await tester.tap(find.text("Submit"));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text("write_release_notes"), findsOneWidget);
  });

  testWidgets("presents a queued question after answering an active permission", (tester) async {
    final questionController = StreamController<SesoriQuestionAsked>.broadcast();
    final permissionController = StreamController<SesoriPermissionAsked>.broadcast();
    addTearDown(questionController.close);
    addTearDown(permissionController.close);
    var state = _loadedState(pendingQuestions: const [], pendingPermissions: const []);
    when(() => cubit.state).thenAnswer((_) => state);
    when(() => cubit.questionStream).thenAnswer((_) => questionController.stream);
    when(() => cubit.permissionStream).thenAnswer((_) => permissionController.stream);
    when(
      () => cubit.replyToPermission(
        requestId: "permission-1",
        sessionId: "session-1",
        reply: PermissionReply.once,
      ),
    ).thenAnswer((_) async {
      state = state.copyWith(pendingPermissions: const []);
      return true;
    });

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    state = state.copyWith(pendingPermissions: const [_permission]);
    permissionController.add(_permission);
    await tester.pumpAndSettle();
    expect(find.text("write_release_notes"), findsOneWidget);

    state = state.copyWith(pendingQuestions: const [_question]);
    questionController.add(_question);
    await tester.pumpAndSettle();
    expect(find.text("Choose a release channel"), findsNothing);

    await tester.tap(find.text("Once"));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text("Choose a release channel"), findsOneWidget);
  });

  // Only the input container is grouped with the text field via a
  // TextFieldTapRegion, so tapping the send button does not fire the field's
  // default `onTapOutside` (which unfocuses and dismisses the keyboard) —
  // without the region, send flickered the keyboard (hide then re-show). The
  // agent/model/variant pills live in the composer header, outside the region,
  // so tapping them is a tap "outside" the field and dismisses the keyboard by
  // design.
  FocusNode composerFocus(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).focusNode;

  // A fresh session rests in the hold-to-talk pill, which hosts no text field;
  // the keyboard button switches the composer to its typing layout and focuses
  // the field (focus lands post-frame).
  Future<void> enterTypingMode(WidgetTester tester) async {
    await tester.tap(find.byIcon(TablerRegular.keyboard));
    await tester.pumpAndSettle();
  }

  testWidgets("pressing send keeps the composer field focused", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Focus the field — the keyboard would rise.
    await enterTypingMode(tester);
    expect(composerFocus(tester).hasFocus, isTrue);

    // Send with an empty field: `_handleSend` is a no-op that does not
    // re-request focus, so focus retention here proves the tap itself didn't
    // unfocus the field (which is what produced the hide/re-show flicker).
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();
    expect(composerFocus(tester).hasFocus, isTrue, reason: "send must not dismiss the keyboard");
  });

  testWidgets("system back dismisses the composer keyboard before popping the route", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit, startAtPreviousScreen: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Open session"));
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    final focusNode = composerFocus(tester);
    expect(focusNode.hasFocus, isTrue);
    final fieldContext = tester.element(find.byType(EditableText));
    expect(Theme.of(fieldContext).platform, TargetPlatform.android);

    // Focus changes before the platform reports the raised IME. The composer
    // must subscribe to this later visibility update so its PopScope activates.
    KeyboardVisibilityTesting.setVisibilityForTesting(true);
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isFalse);
    expect(find.byType(SessionDetailBody), findsOneWidget);
    expect(find.text("Open session"), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(SessionDetailBody), findsNothing);
    expect(find.text("Open session"), findsOneWidget);
  });

  testWidgets("toolbar back pops the route while the Android keyboard is visible", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit, startAtPreviousScreen: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Open session"));
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    expect(composerFocus(tester).hasFocus, isTrue);
    KeyboardVisibilityTesting.setVisibilityForTesting(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();

    expect(find.byType(SessionDetailBody), findsNothing);
    expect(find.text("Open session"), findsOneWidget);
  });

  testWidgets("iOS back navigation stays available while the composer is focused", (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_buildApp(cubit: cubit, startAtPreviousScreen: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Open session"));
      await tester.pumpAndSettle();
      await enterTypingMode(tester);
      expect(composerFocus(tester).hasFocus, isTrue);
      KeyboardVisibilityTesting.setVisibilityForTesting(true);
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(SessionDetailBody), findsNothing);
      expect(find.text("Open session"), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets("opening a composer menu dismisses the keyboard (glass path)", (tester) async {
    // Force the iOS glass path: there PregoAnchorMenu opens GlassMenu as an
    // overlay (not a route), so the only thing that can dismiss the keyboard is
    // the field's `onTapOutside` firing because the pill sits outside the
    // TextFieldTapRegion. That makes this the precise guard that the menus are
    // NOT grouped with the field. (On the Android flat path the menu is a modal
    // route that moves focus anyway, so it can't tell the two designs apart.)
    // Reset in a finally so a failed expect can't leak the override into later
    // tests (the binding asserts foundation debug vars are clear before
    // tearDowns run).
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_buildApp(cubit: cubit));
      await tester.pumpAndSettle();

      await enterTypingMode(tester);
      expect(composerFocus(tester).hasFocus, isTrue);

      // Tapping the variant pill opens its glass popup and, because the pill is
      // outside the field's tap region, dismisses the keyboard. The unfocused,
      // empty composer then collapses back to its resting pill, unmounting the
      // field — which is the proof the focus was dropped.
      await tester.tap(find.widgetWithText(GlassButton, "xhigh"));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(GlassMenuItem, "xhigh"), findsOneWidget);
      expect(
        find.byType(EditableText),
        findsNothing,
        reason: "opening a composer menu must dismiss the keyboard and collapse the composer",
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets("fresh session rests in hold-to-talk and the keyboard button enters typing", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Hold-to-talk pill: no text field, no mic/send circles — the pill itself
    // records and the keyboard button switches to typing.
    expect(find.byType(EditableText), findsNothing);
    expect(find.text("Hold to talk"), findsOneWidget);
    expect(find.byIcon(TablerRegular.arrow_up), findsNothing);

    await enterTypingMode(tester);

    expect(find.byType(EditableText), findsOneWidget);
    expect(composerFocus(tester).hasFocus, isTrue);
    expect(find.byIcon(TablerRegular.arrow_up), findsOneWidget);
    // Voice-first typing nests a hold-to-talk pill along the bottom instead
    // of the text-first mic button.
    expect(find.byIcon(TablerRegular.microphone), findsNothing);
    expect(find.text("Hold to talk"), findsOneWidget);
  });

  testWidgets("voice-first session with messages still rests in hold-to-talk", (tester) async {
    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      messages: [testMessageWithParts()],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.text("Hold to talk"), findsOneWidget);
    expect(find.text("Follow up..."), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets("text-first session with messages rests as a follow-up field that expands on tap", (tester) async {
    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      messages: [testMessageWithParts()],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit, chatInputMode: ChatInputMode.textFirst));
    await tester.pumpAndSettle();

    expect(find.text("Hold to talk"), findsNothing);
    expect(find.text("Follow up..."), findsOneWidget);

    await tester.tap(find.text("Follow up..."));
    await tester.pumpAndSettle();

    expect(find.byType(EditableText), findsOneWidget);
    expect(composerFocus(tester).hasFocus, isTrue);
  });

  testWidgets("text-first fresh session rests as a tap-to-type field with the mic alongside", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit, chatInputMode: ChatInputMode.textFirst));
    await tester.pumpAndSettle();

    expect(find.text("Hold to talk"), findsNothing);
    expect(find.byIcon(TablerRegular.microphone), findsOneWidget);
    expect(find.text("Ask anything..."), findsOneWidget);

    await tester.tap(find.text("Ask anything..."));
    await tester.pumpAndSettle();

    expect(find.byType(EditableText), findsOneWidget);
    expect(composerFocus(tester).hasFocus, isTrue);
  });

  testWidgets("busy composer shows stop instead of send and forwards abort", (tester) async {
    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      messages: [testMessageWithParts()],
      sessionStatus: const SessionStatus.busy(),
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);
    when(() => cubit.abort()).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    // Bounded pumps throughout: the busy status keeps an activity indicator
    // animating in the message area, so pumpAndSettle would never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Nothing to send yet, so the dark action button is the stop control —
    // reachable next to the keyboard button even in the resting voice pill.
    expect(find.byIcon(TablerRegular.arrow_up), findsNothing);
    await tester.tap(find.byIcon(TablerSolid.player_stop));
    verify(() => cubit.abort()).called(1);

    // Typed text flips the same button back to send: sending queues while the
    // agent works, so it must stay reachable.
    await tester.tap(find.byIcon(TablerRegular.keyboard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(EditableText), "follow-up");
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(TablerRegular.arrow_up), findsOneWidget);
    expect(find.byIcon(TablerSolid.player_stop), findsNothing);
  });

  testWidgets("a very short tap starts recording immediately but never transcribes", (tester) async {
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    verify(() => voiceTranscriptionService.startRecording()).called(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();

    verify(() => voiceTranscriptionService.cancelRecording()).called(1);
    verifyNever(() => voiceTranscriptionService.stopAndTranscribe());
  });

  testWidgets("a secondary pointer button does not start recording", (tester) async {
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text("Hold to talk")),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    verifyNever(() => voiceTranscriptionService.startRecording());
    verifyNever(() => voiceTranscriptionService.cancelRecording());
    verifyNever(() => voiceTranscriptionService.stopAndTranscribe());
  });

  testWidgets("the recording morph starts while the recorder is still starting", (tester) async {
    final startCompleter = Completer<void>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) => startCompleter.future);
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump();

    expect(find.byType(VoiceCancelButton), findsOneWidget);
    expect(find.byType(PregoVoiceWaveform), findsOneWidget);
    expect(find.text("Release to transcribe"), findsOneWidget);
    expect(find.byIcon(TablerRegular.keyboard), findsNothing);

    final recordingSwitcher = tester.widget<AnimatedSwitcher>(
      find.byWidgetPredicate(
        (widget) => widget is AnimatedSwitcher && widget.child?.key == const ValueKey("cancel-target"),
      ),
    );
    expect(recordingSwitcher.duration, const Duration(milliseconds: 220));

    await tester.pump(const Duration(milliseconds: 110));
    final recordingFades = tester.widgetList<FadeTransition>(
      find.ancestor(of: find.byType(VoiceCancelButton), matching: find.byType(FadeTransition)),
    );
    expect(
      recordingFades.any((transition) => transition.opacity.value > 0 && transition.opacity.value < 1),
      isTrue,
    );

    await tester.tap(find.byType(VoiceCancelButton));
    await tester.pump();
    verifyNever(() => voiceTranscriptionService.cancelRecording());

    startCompleter.complete();
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    verify(() => voiceTranscriptionService.cancelRecording()).called(1);
    verifyNever(() => voiceTranscriptionService.stopAndTranscribe());
  });

  testWidgets("a short one-word recording still transcribes", (tester) async {
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "yes");

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();

    verify(() => voiceTranscriptionService.stopAndTranscribe()).called(1);
    verifyNever(() => voiceTranscriptionService.cancelRecording());
    expect(find.text("yes"), findsOneWidget);
  });

  testWidgets("release during recorder startup discards the incomplete recording", (tester) async {
    final startCompleter = Completer<void>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) => startCompleter.future);
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Recording is requested on touch-down, then the finger lifts before the
    // recorder finishes starting up.
    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    verify(() => voiceTranscriptionService.startRecording()).called(1);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();
    verifyNever(() => voiceTranscriptionService.stopAndTranscribe());

    // The recorder finishes starting after the finger already lifted, so the
    // incomplete local recording is discarded instead of uploaded.
    startCompleter.complete();
    await tester.pump();
    await tester.pumpAndSettle();
    verify(() => voiceTranscriptionService.cancelRecording()).called(1);
    verifyNever(() => voiceTranscriptionService.stopAndTranscribe());
  });

  testWidgets("restored mixed draft keeps voice-assisted input mode when sent", (tester) async {
    when(() => cubit.composerDraft).thenReturn(
      ComposerDraft(
        text: "typed transcript",
        voiceSpans: [VoiceOriginSpan(start: 6, end: 16)],
      ),
    );
    when(
      () => cubit.sendMessage(
        text: "typed transcript",
        command: null,
        inputMode: ComposerInputMode.voiceAssisted,
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    expect(find.text("typed transcript"), findsOneWidget);

    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();

    verify(
      () => cubit.sendMessage(
        text: "typed transcript",
        command: null,
        inputMode: ComposerInputMode.voiceAssisted,
      ),
    ).called(1);
  });

  testWidgets("replacing a restored voice draft resets input mode", (tester) async {
    when(() => cubit.composerDraft).thenReturn(
      ComposerDraft(
        text: "transcript",
        voiceSpans: [VoiceOriginSpan(start: 0, end: 10)],
      ),
    );
    when(
      () => cubit.sendMessage(
        text: "typed replacement",
        command: null,
        inputMode: ComposerInputMode.typed,
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: editable.controller.text.length,
    );
    await tester.enterText(find.byType(EditableText), "typed replacement");
    await tester.pump();
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();

    verify(
      () => cubit.sendMessage(
        text: "typed replacement",
        command: null,
        inputMode: ComposerInputMode.typed,
      ),
    ).called(1);
  });

  testWidgets("trimmed voice-only whitespace does not make a typed submission voice-assisted", (tester) async {
    when(() => cubit.composerDraft).thenReturn(
      ComposerDraft(
        text: " typed",
        voiceSpans: [VoiceOriginSpan(start: 0, end: 1)],
      ),
    );
    when(
      () => cubit.sendMessage(
        text: "typed",
        command: null,
        inputMode: ComposerInputMode.typed,
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();

    verify(
      () => cubit.sendMessage(
        text: "typed",
        command: null,
        inputMode: ComposerInputMode.typed,
      ),
    ).called(1);
  });

  testWidgets("a second hold during recorder startup does not start a second recording", (tester) async {
    final startCompleter = Completer<void>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) => startCompleter.future);
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) async {});

    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      messages: [testMessageWithParts()],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    // Text-first keeps the mic button as the hold surface.
    await tester.pumpWidget(_buildApp(cubit: cubit, chatInputMode: ChatInputMode.textFirst));
    await tester.pumpAndSettle();

    // First hold on the mic reaches the recorder; a second press (e.g. a
    // second finger on the same surface after a stray release) while the
    // recorder is still starting must not start again.
    final first = await tester.startGesture(tester.getCenter(find.byIcon(TablerRegular.microphone)));
    await tester.pump(const Duration(milliseconds: 100));
    await first.up();
    await tester.pump();
    final second = await tester.startGesture(tester.getCenter(find.byIcon(TablerRegular.microphone)));
    await tester.pump(const Duration(milliseconds: 100));
    await second.up();
    await tester.pump();
    verify(() => voiceTranscriptionService.startRecording()).called(1);

    // Both holds released before startup finished, so the incomplete
    // recording is discarded as soon as startup settles.
    startCompleter.complete();
    await tester.pump();
    verify(() => voiceTranscriptionService.cancelRecording()).called(1);
    await tester.pumpAndSettle();
  });

  testWidgets("a recorder-start failure reverts eager feedback and does not block later recordings", (
    tester,
  ) async {
    final firstStartCompleter = Completer<void>();
    var startCalls = 0;
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) {
      startCalls++;
      return startCalls == 1 ? firstStartCompleter.future : Future<void>.value();
    });
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "");

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // The eager morph runs while native startup is pending.
    final first = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump();
    expect(find.byType(VoiceCancelButton), findsOneWidget);

    // A later platform/filesystem failure reverts the optimistic presentation,
    // surfaces the error, and releases the startup guard.
    firstStartCompleter.completeError(StateError("recorder unavailable"));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceCancelButton), findsNothing);
    expect(find.text("Hold to talk"), findsOneWidget);
    expect(find.text("Recording failed. Please try again."), findsOneWidget);
    expect(tester.takeException(), isNull);

    await first.up();
    await tester.pump();

    // Let the error snackbar time out — it floats over the composer pill and
    // would swallow the next hold.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // A later hold reaches the recorder again.
    final second = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    expect(startCalls, 2);
    await second.up();
    await tester.pumpAndSettle();
  });

  testWidgets("accordion reveals the slash-commands action and opens the picker", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.byIcon(TablerRegular.slash), findsNothing);

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    expect(find.byIcon(TablerRegular.slash), findsOneWidget);

    await tester.tap(find.byIcon(TablerRegular.slash));
    // Bounded pumps: the picker sheet shows a loading shimmer while its
    // entries are prepared, which never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("Slash commands"), findsOneWidget);
  });

  testWidgets("expand button opens the fullscreen editor sharing the composer text", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await tester.enterText(find.byType(EditableText), "long prompt");
    await tester.pump();

    await tester.tap(find.byIcon(TablerRegular.maximize));
    await tester.pumpAndSettle();

    expect(find.byType(PromptEditorSheet), findsOneWidget);
    // The sheet edits the same controller, so it shows the composer's text.
    expect(
      find.descendant(of: find.byType(PromptEditorSheet), matching: find.text("long prompt")),
      findsOneWidget,
    );
  });

  testWidgets("recording swaps the pill chrome for the cancel target and waveform", (tester) async {
    final stopCompleter = Completer<String>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    // Let the swap-in transitions finish (bounded: the waveform never settles).
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(VoiceCancelButton), findsOneWidget);
    // The cancel target must keep the full 44pt footprint (a CustomPaint with
    // a child would otherwise shrink to its icon).
    expect(tester.getSize(find.byType(VoiceCancelButton)), const Size(44, 44));
    expect(find.byType(PregoVoiceWaveform), findsOneWidget);
    expect(find.text("Release to transcribe"), findsOneWidget);
    // The keyboard button leaves the pill while the waveform needs its width.
    expect(find.byIcon(TablerRegular.keyboard), findsNothing);

    await gesture.up();
    await tester.pump();
    stopCompleter.complete("dictated words");
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text("dictated words"), findsOneWidget);
  });

  testWidgets("dragging the hold onto the cancel target discards the recording", (tester) async {
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));

    await gesture.moveTo(tester.getCenter(find.byType(VoiceCancelButton)));
    await tester.pump();
    expect(find.text("Release to cancel"), findsOneWidget);

    await gesture.up();
    await tester.pump();
    verify(() => voiceTranscriptionService.cancelRecording()).called(1);
    verifyNever(() => voiceTranscriptionService.stopAndTranscribe());

    // The pill rests again with nothing transcribed.
    await tester.pumpAndSettle();
    expect(find.text("Hold to talk"), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets("dragging toward cancel during recorder startup is preserved", (tester) async {
    final startCompleter = Completer<void>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) => startCompleter.future);
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "");
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final cancelPosition = tester.getCenter(find.byIcon(TablerRegular.chevron_right));
    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await gesture.moveTo(cancelPosition);
    await tester.pump();

    // The recorder starts after the finger has already reached the future
    // cancel target. No further movement should be needed to preserve that
    // intent or update the drag feedback.
    startCompleter.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text("Release to cancel"), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    verify(() => voiceTranscriptionService.cancelRecording()).called(1);
    verifyNever(() => voiceTranscriptionService.stopAndTranscribe());
  });

  testWidgets("a hold during an in-flight cancel does not present a phantom recording", (tester) async {
    final cancelCompleter = Completer<void>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) => cancelCompleter.future);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Record, then discard by releasing on the cancel target.
    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.byType(VoiceCancelButton)));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    verify(() => voiceTranscriptionService.startRecording()).called(1);

    // The platform cancel is still in flight: the service would silently
    // ignore a start, so the composer must not enter a recording that never
    // began.
    final second = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await second.up();
    await tester.pump();
    verifyNever(() => voiceTranscriptionService.startRecording());

    // Once the cancel settles, recording works again.
    cancelCompleter.complete();
    await tester.pumpAndSettle();
    final third = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    verify(() => voiceTranscriptionService.startRecording()).called(1);
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "");
    await third.up();
    await tester.pumpAndSettle();
  });

  testWidgets("transcribing shows the shimmer and its X discards the transcription", (tester) async {
    final stopCompleter = Completer<String>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    // Bounded pumps: the transcribing shimmer sweeps until the upload ends.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Transcribing..."), findsOneWidget);
    // The keyboard affordance returns while transcription runs.
    expect(find.byIcon(TablerRegular.keyboard), findsOneWidget);

    await tester.tap(find.byIcon(TablerRegular.x));
    await tester.pump();
    verify(() => voiceTranscriptionService.cancelRecording()).called(1);

    // The cancel path resets the composer without waiting for the in-flight
    // upload (the real service fails it with a cancellation error).
    await tester.pumpAndSettle();
    expect(find.text("Hold to talk"), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets("a cancelled transcription settling late cannot corrupt the next recording", (tester) async {
    final stopCompleters = <Completer<String>>[];
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) {
      final completer = Completer<String>();
      stopCompleters.add(completer);
      return completer.future;
    });
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Record and release into a slow transcription, then discard it.
    final first = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await first.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(TablerRegular.x));
    await tester.pumpAndSettle();

    // Start a new recording, then let the cancelled upload settle mid-hold:
    // its continuation must neither insert the stale transcript nor reset
    // this newer interaction back to idle.
    final second = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    stopCompleters.first.complete("stale words");
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(VoiceCancelButton), findsOneWidget);
    expect(find.text("Release to transcribe"), findsOneWidget);

    // The new interaction still completes normally.
    await second.up();
    await tester.pump();
    stopCompleters.last.complete("fresh words");
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text("fresh words"), findsOneWidget);
    expect(find.textContaining("stale words"), findsNothing);
  });

  testWidgets("the keyboard button enters typing while transcription continues", (tester) async {
    final stopCompleter = Completer<String>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(TablerRegular.keyboard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EditableText), findsOneWidget);
    expect(composerFocus(tester).hasFocus, isTrue);

    // The transcript lands in the already-focused field.
    stopCompleter.complete("dictated words");
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text("dictated words"), findsOneWidget);
    expect(composerFocus(tester).hasFocus, isTrue);
  });

  testWidgets("switching the chat input mode re-shapes the resting composer live", (tester) async {
    final modeCubit = StubChatInputModeCubit();

    await tester.pumpWidget(_buildApp(cubit: cubit, chatInputModeCubit: modeCubit));
    await tester.pumpAndSettle();
    expect(find.text("Hold to talk"), findsOneWidget);

    await modeCubit.select(mode: ChatInputMode.textFirst);
    await tester.pumpAndSettle();

    expect(find.text("Hold to talk"), findsNothing);
    expect(find.text("Ask anything..."), findsOneWidget);
    expect(find.byIcon(TablerRegular.microphone), findsOneWidget);
  });

  testWidgets("holding the typing container's voice pill records while the text stays", (tester) async {
    final stopCompleter = Completer<String>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    await tester.enterText(find.byType(EditableText), "draft");
    await tester.pump();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk more")));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));

    // The field (and its text) stay while the bottom pill hosts the chrome.
    expect(find.byType(EditableText), findsOneWidget);
    expect(find.text("draft"), findsOneWidget);
    expect(find.byType(VoiceCancelButton), findsOneWidget);
    expect(find.byType(PregoVoiceWaveform), findsOneWidget);
    expect(find.text("Release to transcribe"), findsOneWidget);
    expect(find.byIcon(TablerRegular.arrow_up), findsNothing);

    await gesture.up();
    await tester.pump();
    stopCompleter.complete("more words");
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text("draft more words"), findsOneWidget);
  });

  testWidgets("voice-first transcript rests unfocused for review before sending", (tester) async {
    final stopCompleter = Completer<String>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();

    stopCompleter.complete("dictated words");
    await tester.pump();
    await tester.pumpAndSettle();

    // The transcript rests in the typing container for review: send is one
    // tap away, the keyboard only rises if the text itself is tapped.
    expect(find.text("dictated words"), findsOneWidget);
    expect(find.byIcon(TablerRegular.arrow_up), findsOneWidget);
    expect(composerFocus(tester).hasFocus, isFalse);
    expect(find.text("Hold to talk more"), findsOneWidget);
  });
}
