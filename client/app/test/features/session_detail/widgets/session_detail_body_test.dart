import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/session_detail/widgets/prompt_editor_sheet.dart";
import "package:sesori_mobile/features/session_detail/widgets/session_detail_body.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/test_helpers.dart";

class MockSessionDetailCubit extends MockCubit<SessionDetailState> implements SessionDetailCubit {}

class MockVoiceTranscriptionService extends Mock implements VoiceTranscriptionService {}

Widget _buildApp({required SessionDetailCubit cubit}) {
  final router = GoRouter(
    routes: [
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

  return BlocProvider<ConnectionOverlayCubit>(
    create: (_) => StubConnectionOverlayCubit(),
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
    expect(find.byIcon(TablerRegular.microphone), findsOneWidget);
  });

  testWidgets("session with messages rests as a follow-up field that expands on tap", (tester) async {
    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      messages: [testMessageWithParts()],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.text("Hold to talk"), findsNothing);
    expect(find.text("Follow up..."), findsOneWidget);

    await tester.tap(find.text("Follow up..."));
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

    // Nothing to send yet, so the dark action button is the stop control.
    expect(find.byIcon(TablerRegular.arrow_up), findsNothing);
    await tester.tap(find.byIcon(TablerSolid.player_stop));
    verify(() => cubit.abort()).called(1);

    // Typed text flips the same button back to send: sending queues while the
    // agent works, so it must stay reachable.
    await tester.tap(find.text("Follow up..."));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(EditableText), "follow-up");
    await tester.pump();
    expect(find.byIcon(TablerRegular.arrow_up), findsOneWidget);
    expect(find.byIcon(TablerSolid.player_stop), findsNothing);
  });

  testWidgets("release during recorder startup still stops the recording", (tester) async {
    final startCompleter = Completer<void>();
    final stopCompleter = Completer<String>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) => startCompleter.future);
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Hold the hold-to-talk pill long enough for the long-press to fire (the
    // recording start is now awaiting the recorder), then release before the
    // recorder finishes starting up.
    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
    verifyNever(() => voiceTranscriptionService.stopAndTranscribe());

    // The recorder finishes starting after the finger already lifted — the
    // composer must stop immediately instead of recording open-endedly.
    startCompleter.complete();
    await tester.pump();
    verify(() => voiceTranscriptionService.stopAndTranscribe()).called(1);

    stopCompleter.complete("transcript");
    await tester.pumpAndSettle();
    expect(find.text("transcript"), findsOneWidget);
    verify(cubit.reportVoiceTranscriptionCompleted).called(1);
    final savedDrafts = verify(
      () => cubit.saveComposerDraft(draft: captureAny(named: "draft")),
    ).captured.cast<ComposerDraft>();
    expect(savedDrafts.last.text, "transcript");
    expect(savedDrafts.last.voiceSpans, [VoiceOriginSpan(start: 0, end: 10)]);
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

  testWidgets("a second hold during recorder startup does not start a second recording", (tester) async {
    final startCompleter = Completer<void>();
    final stopCompleter = Completer<String>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) => startCompleter.future);
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      messages: [testMessageWithParts()],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // First hold on the mic reaches the recorder; a second long-press (e.g. a
    // second finger on the same surface after a stray release) while the
    // recorder is still starting must not start again.
    final first = await tester.startGesture(tester.getCenter(find.byIcon(TablerRegular.microphone)));
    await tester.pump(const Duration(milliseconds: 600));
    await first.up();
    await tester.pump();
    final second = await tester.startGesture(tester.getCenter(find.byIcon(TablerRegular.microphone)));
    await tester.pump(const Duration(milliseconds: 600));
    await second.up();
    await tester.pump();
    verify(() => voiceTranscriptionService.startRecording()).called(1);

    // Both holds released before startup finished — the pending release stops
    // the recording as soon as it begins.
    startCompleter.complete();
    await tester.pump();
    verify(() => voiceTranscriptionService.stopAndTranscribe()).called(1);

    stopCompleter.complete("transcript");
    await tester.pumpAndSettle();
  });

  testWidgets("an unexpected recorder-start failure does not block later recordings", (tester) async {
    var startCalls = 0;
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {
      startCalls++;
      if (startCalls == 1) throw StateError("recorder unavailable");
    });
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "");

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // First hold fails with an error outside the typed voice errors — it must
    // be handled (error snackbar) rather than escaping and leaving the start
    // guards stuck.
    final first = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await first.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

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
}
