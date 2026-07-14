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
}) {
  final provider = testProviderListResponse().items.first;
  return SessionDetailLoaded(
    messages: const [],
    streamingText: const {},
    sessionStatus: const SessionStatus.idle(),
    pendingQuestions: pendingQuestions,
    pendingPermissions: pendingPermissions,
    sessionTitle: "Session",
    agent: null,
    assistantAgentModel: null,
    children: const [],
    childStatuses: const {},
    isRootSession: true,
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

    final maxDurationReached = StreamController<void>.broadcast();
    addTearDown(maxDurationReached.close);
    when(() => voiceTranscriptionService.onMaxDurationReached).thenAnswer((_) => maxDurationReached.stream);

    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
    GetIt.instance.registerLazySingleton<DraftStore>(DraftStore.new);
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

  // Only the input row is grouped with the text field via a TextFieldTapRegion,
  // so tapping the send button does not fire the field's default `onTapOutside`
  // (which unfocuses and dismisses the keyboard) — without the region, send
  // flickered the keyboard (hide then re-show). The agent/model/variant pills
  // live in the composer header, outside the region, so tapping them is a tap
  // "outside" the field and dismisses the keyboard by design.
  FocusNode composerFocus(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).focusNode;

  testWidgets("pressing send keeps the composer field focused", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Focus the field — the keyboard would rise.
    await tester.tap(find.byType(EditableText));
    await tester.pump();
    expect(composerFocus(tester).hasFocus, isTrue);

    // Send with an empty field: `_handleSend` is a no-op that does not
    // re-request focus, so focus retention here proves the tap itself didn't
    // unfocus the field (which is what produced the hide/re-show flicker).
    await tester.tap(find.byIcon(Icons.send));
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

      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(composerFocus(tester).hasFocus, isTrue);

      // Tapping the variant pill opens its glass popup and, because the pill is
      // outside the field's tap region, dismisses the keyboard.
      await tester.tap(find.widgetWithText(GlassButton, "xhigh"));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(GlassMenuItem, "xhigh"), findsOneWidget);
      expect(composerFocus(tester).hasFocus, isFalse, reason: "opening a composer menu must dismiss the keyboard");
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
