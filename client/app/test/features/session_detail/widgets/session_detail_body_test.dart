import "dart:async";
import "dart:ui" show PointerDeviceKind;

import "package:bloc_test/bloc_test.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart" show kSecondaryButton;
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/media/composer_image_picker.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/session_detail/widgets/background_tasks_bar.dart";
import "package:sesori_mobile/features/session_detail/widgets/prompt_editor_sheet.dart";
import "package:sesori_mobile/features/session_detail/widgets/prompt_input.dart";
import "package:sesori_mobile/features/session_detail/widgets/queued_message_bubble.dart";
import "package:sesori_mobile/features/session_detail/widgets/session_detail_body.dart";
import "package:sesori_mobile/features/session_detail/widgets/session_detail_message_list.dart";
import "package:sesori_mobile/features/session_detail/widgets/text_part_widget.dart";
import "package:sesori_mobile/features/session_detail/widgets/user_message_card.dart";
import "package:sesori_mobile/features/session_detail/widgets/voice_cancel_button.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/test_helpers.dart";

class MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

class MockVoiceTranscriptionService() extends Mock implements VoiceTranscriptionService;

class MockComposerImagePicker() extends Mock implements ComposerImagePicker;

class MockImageClipboard() extends Mock implements ImageClipboard;

/// A valid 1x1 transparent PNG so `Image.memory` thumbnails decode in tests.
final Uint8List _tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

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
  List<Session> children = const [],
  Map<String, SessionStatus> childStatuses = const {},
  SessionStatus sessionStatus = const SessionStatus.idle(),
  String? pluginId = "opencode",
  bool? supportsPromptAttachments = true,
}) {
  final provider = testProviderListResponse().items.first;
  return SessionDetailLoaded(
    messages: messages,
    olderMessagesCursor: null,
    streamingText: const {},
    sessionStatus: sessionStatus,
    pendingQuestions: pendingQuestions,
    pendingPermissions: pendingPermissions,
    sessionTitle: "Session",
    pluginId: pluginId,
    supportsPromptAttachments: supportsPromptAttachments,
    agent: null,
    assistantAgentModel: null,
    children: children,
    childStatuses: childStatuses,
    isRootSession: true,
    isArchived: false,
    queuedMessages: const [],
    sendingSubmission: null,
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
    availableVariants: const [
      SessionVariant(id: "xhigh"),
      SessionVariant(id: "low"),
    ],
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

Finder _pickerMenuItem(String label) => find.descendant(
  of: find.byType(SingleChildScrollView),
  matching: find.widgetWithText(InkWell, label),
);

List<Object?> _captureHapticFeedback({required bool throwsPlatformException}) {
  final feedback = <Object?>[];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == "HapticFeedback.vibrate") {
      feedback.add(call.arguments);
      if (throwsPlatformException) throw PlatformException(code: "haptics-unavailable");
    }
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return feedback;
}

void main() {
  late MockSessionDetailCubit cubit;
  late MockVoiceTranscriptionService voiceTranscriptionService;
  late MockComposerImagePicker imagePicker;
  late MockImageClipboard imageClipboard;
  late StreamController<void> maxDurationReached;

  setUpAll(() {
    registerFallbackValue(ComposerDraft.typed(text: ""));
    registerFallbackValue(ComposerInputMode.typed);
  });

  Finder semanticsWithLabel(String label) =>
      find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

  // Composer pickers force PregoAnchorMenu's flat cue path on every platform,
  // so the menu rows are Material InkWells.
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
    when(() => cubit.noticeStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
    when(
      () => cubit.saveComposerDraft(draft: any(named: "draft")),
    ).thenReturn(null);
    when(cubit.clearComposerDraft).thenReturn(null);
    when(cubit.reportVoiceTranscriptionCompleted).thenReturn(null);

    maxDurationReached = StreamController<void>.broadcast();
    addTearDown(maxDurationReached.close);
    when(() => voiceTranscriptionService.onMaxDurationReached).thenAnswer((_) => maxDurationReached.stream);
    when(() => voiceTranscriptionService.prewarmRecording()).thenAnswer((_) async {});

    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);

    imagePicker = MockComposerImagePicker();
    GetIt.instance.registerSingleton<ComposerImagePicker>(imagePicker);

    imageClipboard = MockImageClipboard();
    when(imageClipboard.readImage).thenAnswer((_) async => null);
    GetIt.instance.registerSingleton<ImageClipboard>(imageClipboard);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets("PromptInput consumes initial attachments once per identity or restoration", (tester) async {
    final first = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: "first.png");
    final second = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: "second.png");
    final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.subtle);
    addTearDown(surfaceStyle.dispose);
    var consumed = 0;
    ComposerDraft? submittedDraft;
    List<ComposerAttachment>? submitted;

    Widget buildPrompt({
      required String draftIdentity,
      required Key? restorationKey,
      required ComposerDraft draft,
      required List<ComposerAttachment> attachments,
    }) {
      return MultiBlocProvider(
        providers: [
          BlocProvider<ChatInputModeCubit>(create: (_) => StubChatInputModeCubit()),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PromptInput(
              isBusy: false,
              hasMessages: false,
              onSend: ({required draft, required command, required attachments}) {
                submittedDraft = draft;
                submitted = attachments;
              },
              onVoiceTranscriptionCompleted: () {},
              onDraftChanged: (_) {},
              onDraftCleared: () {},
              onAbort: () {},
              surfaceStyleController: surfaceStyle,
              composerHeader: null,
              availableCommands: const [],
              stagedCommand: null,
              onCommandSelected: (_) {},
              onCommandCleared: () {},
              attachmentsSupported: true,
              draftIdentity: draftIdentity,
              restorationKey: restorationKey,
              initialDraft: draft,
              initialAttachments: attachments,
              onInitialAttachmentsConsumed: () => consumed++,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      buildPrompt(
        draftIdentity: "first",
        restorationKey: null,
        draft: ComposerDraft.typed(text: ""),
        attachments: [first],
      ),
    );
    await tester.pump();
    expect(consumed, 1);

    await tester.pumpWidget(
      buildPrompt(
        draftIdentity: "first",
        restorationKey: null,
        draft: ComposerDraft.typed(text: ""),
        attachments: [first],
      ),
    );
    await tester.pump();
    expect(consumed, 1);

    final mixedDraft = ComposerDraft(
      text: " voice typed ",
      voiceSpans: [VoiceOriginSpan(start: 1, end: 6)],
    );
    surfaceStyle.value = PregoComposerSurfaceStyle.subtle;
    await tester.pumpWidget(
      buildPrompt(
        draftIdentity: "first",
        restorationKey: const ValueKey("failed-submission"),
        draft: mixedDraft,
        attachments: [second],
      ),
    );
    await tester.pump();
    expect(consumed, 2);
    expect(surfaceStyle.value, PregoComposerSurfaceStyle.emphasized);

    await tester.pumpWidget(
      buildPrompt(
        draftIdentity: "first",
        restorationKey: null,
        draft: mixedDraft,
        attachments: [second],
      ),
    );
    await tester.pump();
    expect(consumed, 2);

    await tester.pumpWidget(
      buildPrompt(
        draftIdentity: "second",
        restorationKey: null,
        draft: mixedDraft,
        attachments: [second],
      ),
    );
    await tester.pump();
    expect(consumed, 3);

    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();
    expect(
      submittedDraft,
      ComposerDraft(
        text: "voice typed",
        voiceSpans: [VoiceOriginSpan(start: 0, end: 5)],
      ),
    );
    expect(submitted, hasLength(1));
    expect(identical(submitted!.single, second), isTrue);
  });

  testWidgets("an empty user envelope keeps the empty transcript state visible", (tester) async {
    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      messages: const [
        MessageWithParts(
          info: Message.user(
            promptId: null,
            id: "empty-user-envelope",
            sessionID: "session-1",
            agent: null,
            time: null,
          ),
          parts: [],
        ),
      ],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.text("No messages yet"), findsOneWidget);
  });

  testWidgets("composer fade obscures transcript text behind floating controls", (tester) async {
    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []);
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final decoratedBox = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(PromptInput),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).gradient is LinearGradient,
            ),
          )
          .first,
    );
    final gradient = (decoratedBox.decoration as BoxDecoration).gradient! as LinearGradient;
    final surface = PregoDesignSystem.light.colors.bgSurface1;
    expect(gradient.colors[0], surface.withValues(alpha: 0.98));
    expect(gradient.colors[1], surface.withValues(alpha: 0.88));
    expect(gradient.colors[2], surface.withValues(alpha: 0));
  });

  testWidgets("an empty newest page keeps older transcript paging reachable", (tester) async {
    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      olderMessagesCursor: 42,
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.byType(SessionDetailMessageList), findsOneWidget);
    expect(find.text("No messages yet"), findsNothing);
  });

  testWidgets("sending feedback replaces the empty transcript label", (tester) async {
    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      sendingSubmission: const QueuedSessionSubmission.text(
        promptId: "prompt-1",
        text: "Cold-start prompt",
        inputMode: ComposerInputMode.typed,
        attachments: [],
        agent: "coder",
        agentModel: null,
      ),
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pump();

    expect(find.text("No messages yet"), findsNothing);
    expect(find.text("Cold-start prompt"), findsOneWidget);
  });

  testWidgets("settled user text renders Markdown inside the shared brand bubble", (tester) async {
    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      messages: const [
        MessageWithParts(
          info: Message.user(
            promptId: null,
            id: "markdown-user",
            sessionID: "session-1",
            agent: null,
            time: null,
          ),
          parts: [
            MessagePart.text(
              id: "markdown-user-text",
              sessionID: "session-1",
              messageID: "markdown-user",
              text: "Please **review** `main.dart`",
            ),
          ],
        ),
      ],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(UserMessageBubble), matching: find.byType(MarkdownBody)), findsOneWidget);
    expect(find.textContaining("**review**"), findsNothing);
    expect(find.textContaining("`main.dart`"), findsNothing);
  });

  testWidgets("remote user Markdown images require an explicit open action", (tester) async {
    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      messages: const [
        MessageWithParts(
          info: Message.user(
            promptId: null,
            id: "remote-image-user",
            sessionID: "session-1",
            agent: null,
            time: null,
          ),
          parts: [
            MessagePart.text(
              id: "remote-image-user-text",
              sessionID: "session-1",
              messageID: "remote-image-user",
              text: "![diagram](https://example.com/diagram.png)",
            ),
          ],
        ),
      ],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownMessageImage), findsNothing);
    expect(find.widgetWithText(TextButton, "diagram"), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets("an unknown attachment does not create an empty user bubble", (tester) async {
    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      messages: const [
        MessageWithParts(
          info: Message.user(
            promptId: null,
            id: "unknown-attachment-user",
            sessionID: "session-1",
            agent: null,
            time: null,
          ),
          parts: [
            MessagePart.file(
              id: "unknown-file",
              sessionID: "session-1",
              messageID: "unknown-attachment-user",
              attachment: MessageAttachment.unknown(),
            ),
          ],
        ),
      ],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.text("No messages yet"), findsOneWidget);
  });

  testWidgets("an empty message envelope keeps the first-prompt composer hint", (tester) async {
    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      messages: const [
        MessageWithParts(
          info: Message.user(
            promptId: null,
            id: "empty-user",
            sessionID: "session-1",
            agent: null,
            time: null,
          ),
          parts: [],
        ),
      ],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit, chatInputMode: ChatInputMode.textFirst));
    await tester.pumpAndSettle();

    expect(find.text("Ask anything..."), findsOneWidget);
    expect(find.text("Follow up..."), findsNothing);
  });

  testWidgets("header resolves an opaque assistant model ID through the provider catalog", (tester) async {
    const modelID = "v1WyJkZWVwc2Vlay1vZmZpY2lhbCIsImRlZXBzZWVrLXY0LXBybyJd";
    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      agent: "deepseek",
      assistantAgentModel: const AgentModel(
        providerID: "deepseek-official",
        modelID: modelID,
        variant: "high",
      ),
      availableProviders: const [
        ProviderInfo(
          id: "deepseek-official",
          name: "DeepSeek Official",
          models: {
            modelID: ProviderModel(
              id: modelID,
              providerID: "deepseek-official",
              name: "DeepSeek V4 Pro",
              variants: ["high"],
              family: null,
              releaseDate: null,
            ),
          },
          defaultModelID: modelID,
        ),
      ],
      selectedAgent: "deepseek",
      selectedAgentModel: const AgentModel(
        providerID: "deepseek-official",
        modelID: modelID,
        variant: "high",
      ),
      availableVariants: const [SessionVariant(id: "high")],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.text("deepseek · DeepSeek V4 Pro"), findsOneWidget);
    expect(find.textContaining(modelID), findsNothing);
  });

  testWidgets("opens the variant picker and forwards the selection to the cubit", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Regression guard: the loaded state here has a null agent and model, so
    // the bar subtitle must collapse to empty — never a literal "null".
    expect(find.text("null"), findsNothing);

    await tester.tap(find.widgetWithText(PregoPickerButton, "xhigh"));
    await tester.pumpAndSettle();

    expect(_pickerMenuItem("xhigh"), findsOneWidget);

    await tester.tap(_pickerMenuItem("xhigh"));
    await tester.pumpAndSettle();

    verify(() => cubit.selectVariant(const SessionVariant(id: "xhigh"))).called(1);
  });

  testWidgets("selecting a different variant updates the displayed variant", (tester) async {
    final initialState = _loadedState(pendingQuestions: const [], pendingPermissions: const []);
    final updatedState = SessionDetailState.loaded(
      messages: const [],
      olderMessagesCursor: null,
      streamingText: const {},
      sessionStatus: const SessionStatus.idle(),
      pendingQuestions: const [],
      pendingPermissions: const [],
      sessionTitle: "Session",
      pluginId: "opencode",
      supportsPromptAttachments: false,
      agent: null,
      assistantAgentModel: null,
      children: const [],
      childStatuses: const {},
      isRootSession: true,
      isArchived: false,
      queuedMessages: const [],
      sendingSubmission: null,
      availableAgents: [testAgentInfo()],
      availableProviders: testProviderListResponse().items,
      availableCommands: const [],
      selectedAgent: "coder",
      selectedAgentModel: const AgentModel(
        providerID: "anthropic",
        modelID: "claude-3-5-sonnet",
        variant: "low",
      ),
      stagedCommand: null,
      isRefreshing: false,
      availableVariants: const [
        SessionVariant(id: "xhigh"),
        SessionVariant(id: "low"),
      ],
    );

    final controller = StreamController<SessionDetailState>.broadcast();
    addTearDown(controller.close);
    when(() => cubit.state).thenReturn(initialState);
    when(() => cubit.stream).thenAnswer((_) => controller.stream);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Initially shows the selected variant.
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsOneWidget);

    // Open variant picker.
    await tester.tap(find.widgetWithText(PregoPickerButton, "xhigh"));
    await tester.pumpAndSettle();

    // Select the other available variant.
    await tester.tap(_pickerMenuItem("low"));
    await tester.pumpAndSettle();

    verify(() => cubit.selectVariant(const SessionVariant(id: "low"))).called(1);

    // Emit the updated state to simulate the cubit update.
    when(() => cubit.state).thenReturn(updatedState);
    controller.add(updatedState);
    await tester.pumpAndSettle();

    // The UI should now show the newly selected variant.
    expect(find.widgetWithText(PregoPickerButton, "low"), findsOneWidget);
    expect(find.widgetWithText(PregoPickerButton, "xhigh"), findsNothing);
  });

  testWidgets("diff button navigates to diffs with the typed route", (tester) async {
    final notices = StreamController<SessionDetailNotice>.broadcast();
    addTearDown(notices.close);
    when(() => cubit.noticeStream).thenAnswer((_) => notices.stream);
    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.git_compare));
    await tester.pumpAndSettle();

    expect(find.text("Diffs"), findsOneWidget);

    notices.add(SessionDetailNotice.promptOptionsUpdated);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text("Prompt options changed. Updated settings and retrying your message."),
      findsNothing,
    );
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

  testWidgets("an archived session is read-only: no composer, no pending banners", (tester) async {
    // Archiving is permanent, so an archived session is audit-only.
    final state =
        _loadedState(
          pendingQuestions: const [_question],
          pendingPermissions: const [_permission],
        ).copyWith(
          isArchived: true,
          queuedMessages: const [
            QueuedSessionSubmission.text(
              promptId: "prompt-1",
              text: "Queued before archive",
              inputMode: ComposerInputMode.typed,
              attachments: [],
              agent: "coder",
              agentModel: null,
            ),
          ],
        );
    when(() => cubit.state).thenReturn(state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.byType(PromptInput), findsNothing);
    expect(find.text("This session is archived and read-only."), findsOneWidget);
    // Pending requests can never be answered on an archived session.
    expect(find.text("1 pending question"), findsNothing);
    expect(find.text("1 permission request pending"), findsNothing);
    expect(find.text("Queued before archive"), findsOneWidget);
    expect(find.text("Queued"), findsOneWidget);
    expect(find.widgetWithText(TextButton, "Cancel"), findsNothing);
    expect(
      tester.widget<UserMessageBubble>(find.byType(UserMessageBubble)).outlined,
      isTrue,
    );
  });

  testWidgets("shows an alert when stale prompt options are refreshed automatically", (tester) async {
    final notices = StreamController<SessionDetailNotice>.broadcast();
    addTearDown(notices.close);
    when(() => cubit.noticeStream).thenAnswer((_) => notices.stream);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    notices.add(SessionDetailNotice.promptOptionsUpdated);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text("Prompt options changed. Updated settings and retrying your message."),
      findsOneWidget,
    );
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
    await tester.tap(find.text("Submit answers"));
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

  Color composerSurfaceBorderColor({required WidgetTester tester, required Finder surface}) {
    expect(surface, findsOneWidget);
    final decoratedBox = find.descendant(of: surface, matching: find.byType(DecoratedBox)).first;
    final decoration = tester.widget<DecoratedBox>(decoratedBox).decoration as BoxDecoration;
    final border = decoration.border;
    if (border is! Border) throw TestFailure("Expected a solid composer surface border");
    return border.top.color;
  }

  // A fresh session rests in the hold-to-talk pill, which hosts no text field;
  // the keyboard button switches the composer to its typing layout and focuses
  // the field (focus lands post-frame).
  Future<void> enterTypingMode(WidgetTester tester) async {
    await tester.tap(find.byIcon(TablerRegular.keyboard));
    await tester.pumpAndSettle();
  }

  testWidgets("pressing send keeps the composer field focused", (tester) async {
    when(
      () => cubit.sendMessage(
        text: "ship it",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: const [],
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    // Focus the field — the keyboard would rise.
    await enterTypingMode(tester);
    expect(composerFocus(tester).hasFocus, isTrue);

    await tester.enterText(find.byType(EditableText), "ship it");
    await tester.pump();

    // Focus retention here proves the tap itself didn't unfocus the field
    // (which is what produced the hide/re-show flicker).
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();
    expect(composerFocus(tester).hasFocus, isTrue, reason: "send must not dismiss the keyboard");
  });

  testWidgets("send stays disabled until the composer holds text", (tester) async {
    VoidCallback? sendAction() =>
        tester.widget<PregoButtonsSolid>(find.widgetWithIcon(PregoButtonsSolid, TablerRegular.arrow_up)).onPressed;

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await enterTypingMode(tester);
    expect(sendAction(), isNull, reason: "an empty composer has nothing to send");

    await tester.enterText(find.byType(EditableText), "ship it");
    await tester.pump();
    expect(sendAction(), isNotNull);

    // Whitespace alone is not sendable content either.
    await tester.enterText(find.byType(EditableText), "   ");
    await tester.pump();
    expect(sendAction(), isNull);
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

  testWidgets("opening the shared flat composer menu dismisses the keyboard on iOS", (tester) async {
    // Force iOS to guard that the composer still uses the Android flat menu path
    // there, and that opening its modal route dismisses the field as expected.
    // Reset in a finally so a failed expect can't leak the override into later
    // tests (the binding asserts foundation debug vars are clear before
    // tearDowns run).
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_buildApp(cubit: cubit));
      await tester.pumpAndSettle();

      await enterTypingMode(tester);
      expect(composerFocus(tester).hasFocus, isTrue);

      // The unfocused, empty composer collapses back to its resting pill,
      // unmounting the field, while the Android-style menu remains open.
      await tester.tap(find.widgetWithText(PregoPickerButton, "xhigh"));
      await tester.pumpAndSettle();
      expect(_pickerMenuItem("xhigh"), findsOneWidget);
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

  testWidgets("picker pills and task card follow the composer surface style", (tester) async {
    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      children: [testSession(id: "child-1", title: "Child task", parentID: "session-1")],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final picker = find.byType(PregoPickerButton).first;
    final taskCard = find.descendant(
      of: find.byType(BackgroundTasksBar),
      matching: find.byType(PregoCard),
    );
    expect(
      composerSurfaceBorderColor(tester: tester, surface: picker),
      PregoColorsLight.borderSecondary,
    );
    expect(
      composerSurfaceBorderColor(tester: tester, surface: taskCard),
      PregoColorsLight.borderSecondary,
    );

    await tester.tap(find.byIcon(TablerRegular.keyboard));
    await tester.pump();

    // Adjacent surfaces switch in the same frame as the composer rather than
    // briefly retaining the previous outline treatment.
    expect(
      composerSurfaceBorderColor(tester: tester, surface: picker),
      PregoColorsLight.borderPrimary,
    );
    expect(
      composerSurfaceBorderColor(tester: tester, surface: taskCard),
      PregoColorsLight.borderPrimary,
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), "draft");
    composerFocus(tester).unfocus();
    await tester.pumpAndSettle();

    expect(
      composerSurfaceBorderColor(tester: tester, surface: picker),
      PregoColorsLight.borderPrimary,
    );
    expect(
      composerSurfaceBorderColor(tester: tester, surface: taskCard),
      PregoColorsLight.borderPrimary,
    );

    await tester.tap(find.text("draft"));
    await tester.enterText(find.byType(EditableText), "");
    composerFocus(tester).unfocus();
    await tester.pumpAndSettle();

    expect(
      composerSurfaceBorderColor(tester: tester, surface: picker),
      PregoColorsLight.borderSecondary,
    );
    expect(
      composerSurfaceBorderColor(tester: tester, surface: taskCard),
      PregoColorsLight.borderSecondary,
    );
  });

  testWidgets("parent-driven staged command changes update adjacent surface styles", (tester) async {
    var state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      children: [testSession(id: "child-1", title: "Child task", parentID: "session-1")],
    );
    final stateController = StreamController<SessionDetailState>.broadcast();
    addTearDown(stateController.close);
    when(() => cubit.state).thenAnswer((_) => state);
    when(() => cubit.stream).thenAnswer((_) => stateController.stream);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final picker = find.byType(PregoPickerButton).first;
    final taskCard = find.descendant(
      of: find.byType(BackgroundTasksBar),
      matching: find.byType(PregoCard),
    );
    expect(
      composerSurfaceBorderColor(tester: tester, surface: picker),
      PregoColorsLight.borderSecondary,
    );
    expect(
      composerSurfaceBorderColor(tester: tester, surface: taskCard),
      PregoColorsLight.borderSecondary,
    );

    state = state.copyWith(stagedCommand: testCommandInfo());
    stateController.add(state);
    await tester.pumpAndSettle();

    expect(find.byType(EditableText), findsOneWidget);
    expect(
      composerSurfaceBorderColor(tester: tester, surface: taskCard),
      PregoColorsLight.borderPrimary,
    );

    composerFocus(tester).unfocus();
    await tester.pumpAndSettle();

    state = state.copyWith(stagedCommand: null);
    stateController.add(state);
    await tester.pumpAndSettle();

    expect(find.byType(EditableText), findsNothing);
    expect(
      composerSurfaceBorderColor(tester: tester, surface: picker),
      PregoColorsLight.borderSecondary,
    );
    expect(
      composerSurfaceBorderColor(tester: tester, surface: taskCard),
      PregoColorsLight.borderSecondary,
    );
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
    expect(
      composerSurfaceBorderColor(tester: tester, surface: find.byType(PregoPickerButton).first),
      PregoColorsLight.borderPrimary,
    );
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

  testWidgets("prewarms the voice recorder when the composer mounts", (tester) async {
    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    verify(() => voiceTranscriptionService.prewarmRecording()).called(1);
  });

  testWidgets("voice hold acknowledges touch-down and stays silent for an empty transcript", (tester) async {
    final feedback = _captureHapticFeedback(throwsPlatformException: false);
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "");

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    expect(feedback, ["HapticFeedbackType.lightImpact"]);

    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(feedback, ["HapticFeedbackType.lightImpact"]);
  });

  testWidgets("a successful transcript gives feedback when its text is inserted", (tester) async {
    final feedback = _captureHapticFeedback(throwsPlatformException: false);
    final stopCompleter = Completer<String>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    expect(feedback, ["HapticFeedbackType.lightImpact"]);

    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pump();
    expect(feedback, ["HapticFeedbackType.lightImpact"]);

    stopCompleter.complete("dictated words");
    await tester.pump();

    expect(find.text("dictated words"), findsOneWidget);
    expect(feedback, ["HapticFeedbackType.lightImpact", "HapticFeedbackType.lightImpact"]);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(feedback, [
      "HapticFeedbackType.lightImpact",
      "HapticFeedbackType.lightImpact",
      "HapticFeedbackType.heavyImpact",
    ]);
  });

  testWidgets("crossing into and out of the cancel target gives one tick at each boundary", (tester) async {
    final feedback = _captureHapticFeedback(throwsPlatformException: false);
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "");

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final holdCenter = tester.getCenter(find.text("Hold to talk"));
    final gesture = await tester.startGesture(holdCenter);
    expect(feedback, ["HapticFeedbackType.lightImpact"]);
    await tester.pump(const Duration(milliseconds: 250));

    final cancelCenter = tester.getCenter(find.byType(VoiceCancelButton));
    await gesture.moveTo(cancelCenter);
    expect(feedback, ["HapticFeedbackType.lightImpact", "HapticFeedbackType.selectionClick"]);

    // A small retreat remains armed so finger tremor cannot chatter across the
    // cancel boundary.
    await gesture.moveTo(cancelCenter + const Offset(50, 0));
    await tester.pump();
    expect(find.text("Release to cancel"), findsOneWidget);
    expect(feedback, ["HapticFeedbackType.lightImpact", "HapticFeedbackType.selectionClick"]);

    await gesture.moveTo(holdCenter);
    expect(feedback, [
      "HapticFeedbackType.lightImpact",
      "HapticFeedbackType.selectionClick",
      "HapticFeedbackType.selectionClick",
    ]);

    await gesture.up();
    await tester.pumpAndSettle();
    verify(() => voiceTranscriptionService.stopAndTranscribe()).called(1);
    expect(feedback, [
      "HapticFeedbackType.lightImpact",
      "HapticFeedbackType.selectionClick",
      "HapticFeedbackType.selectionClick",
    ]);
  });

  testWidgets("haptic platform failures do not interrupt voice recording", (tester) async {
    _captureHapticFeedback(throwsPlatformException: true);
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "dictated words");

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    verify(() => voiceTranscriptionService.stopAndTranscribe()).called(1);
    expect(find.text("dictated words"), findsOneWidget);
  });

  testWidgets("transcription cancel after a recovered drag gives a fresh dismiss tick", (tester) async {
    final feedback = _captureHapticFeedback(throwsPlatformException: false);
    final stopCompleter = Completer<String>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final holdCenter = tester.getCenter(find.text("Hold to talk"));
    final gesture = await tester.startGesture(holdCenter);
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.moveTo(tester.getCenter(find.byType(VoiceCancelButton)));
    await gesture.moveTo(holdCenter);
    await gesture.up();
    await tester.pump();

    await tester.tap(find.byTooltip("Cancel transcription"));
    await tester.pump();

    expect(feedback, [
      "HapticFeedbackType.lightImpact",
      "HapticFeedbackType.selectionClick",
      "HapticFeedbackType.selectionClick",
      "HapticFeedbackType.selectionClick",
    ]);

    stopCompleter.complete("stale words");
    await tester.pump();
    expect(find.textContaining("stale words"), findsNothing);
    expect(feedback, [
      "HapticFeedbackType.lightImpact",
      "HapticFeedbackType.selectionClick",
      "HapticFeedbackType.selectionClick",
      "HapticFeedbackType.selectionClick",
    ]);
  });

  testWidgets("a very short tap starts recording immediately but never transcribes", (tester) async {
    final feedback = _captureHapticFeedback(throwsPlatformException: false);
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
    expect(feedback, ["HapticFeedbackType.lightImpact"]);
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

  testWidgets("the recording limit stops and transcribes the active hold", (tester) async {
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "limit words");

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 250));
    maxDurationReached.add(null);
    await tester.pump();
    await tester.pumpAndSettle();

    verify(() => voiceTranscriptionService.stopAndTranscribe()).called(1);
    expect(find.text("Recording limit reached (15 minutes)"), findsOneWidget);
    expect(find.text("limit words"), findsOneWidget);

    await gesture.up();
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
        attachments: const [],
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
        attachments: const [],
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
        attachments: const [],
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
        attachments: const [],
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
        attachments: const [],
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
        attachments: const [],
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

  testWidgets("expanded editor keyboard paste stages an image attachment", (tester) async {
    final attachment = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: null);
    when(imageClipboard.readImage).thenAnswer((_) async => _tinyPng);
    when(
      () => imagePicker.attachmentFromBytes(bytes: _tinyPng, filename: null),
    ).thenReturn(attachment);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    await enterTypingMode(tester);
    await tester.tap(find.byIcon(TablerRegular.maximize));
    await tester.pumpAndSettle();

    final sheetEditor = find.descendant(of: find.byType(PromptEditorSheet), matching: find.byType(EditableText));
    final actionContext = tester.element(
      find.descendant(of: sheetEditor, matching: find.byType(RawGestureDetector)).first,
    );
    Actions.invoke(actionContext, const PasteTextIntent(SelectionChangedCause.keyboard));
    await tester.pumpAndSettle();

    verify(imageClipboard.readImage).called(1);
    verify(() => imagePicker.attachmentFromBytes(bytes: _tinyPng, filename: null)).called(1);
    Navigator.of(tester.element(find.byType(PromptEditorSheet))).pop();
    await tester.pumpAndSettle();
    expect(semanticsWithLabel("Attached image"), findsOneWidget);
  });

  testWidgets("recording swaps the pill chrome for the cancel target and waveform", (tester) async {
    final stopCompleter = Completer<String>();
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final restingComposerHeight = tester.getSize(find.byType(PromptInput)).height;
    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    // Let the swap-in transitions finish (bounded: the waveform never settles).
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.getSize(find.byType(PromptInput)).height, closeTo(restingComposerHeight, 0.01));
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
    expect(
      composerSurfaceBorderColor(tester: tester, surface: find.byType(PregoPickerButton).first),
      PregoColorsLight.borderSecondary,
    );

    await modeCubit.select(mode: ChatInputMode.textFirst);
    await tester.pumpAndSettle();

    expect(find.text("Hold to talk"), findsNothing);
    expect(find.text("Ask anything..."), findsOneWidget);
    expect(find.byIcon(TablerRegular.microphone), findsOneWidget);
    expect(
      composerSurfaceBorderColor(tester: tester, surface: find.byType(PregoPickerButton).first),
      PregoColorsLight.borderPrimary,
    );
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

  testWidgets("long voice-first transcript rests scrolled to its end without focus", (tester) async {
    final transcript = List.generate(80, (index) => "dictated phrase $index").join(" ");
    when(() => voiceTranscriptionService.startRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => transcript);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    final scrollController = editable.scrollController!;
    expect(editable.focusNode.hasFocus, isFalse);
    expect(editable.controller.selection, TextSelection.collapsed(offset: transcript.length));
    expect(scrollController.position.maxScrollExtent, greaterThan(0));
    expect(scrollController.offset, scrollController.position.maxScrollExtent);
  });

  testWidgets("accordion attach action stages a removable thumbnail without raising the keyboard", (tester) async {
    final attachment = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: "screenshot.png");
    when(imagePicker.pickImage).thenAnswer((_) async => attachment);
    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      pluginId: "codex",
      supportsPromptAttachments: true,
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.photo));
    await tester.pumpAndSettle();

    // The staged image switches the composer to the typing layout so the
    // thumbnail is visible, but the keyboard stays down for review parity
    // with the voice transcript flow.
    expect(semanticsWithLabel("screenshot.png"), findsOneWidget);
    expect(find.byIcon(TablerRegular.arrow_up), findsOneWidget);
    expect(composerFocus(tester).hasFocus, isFalse);

    final removeButton = find.descendant(
      of: find.byTooltip("Remove attachment"),
      matching: find.byType(PregoTappable),
    );
    tester.widget<PregoTappable>(removeButton).onTap!.call();
    await tester.pumpAndSettle();
    expect(semanticsWithLabel("screenshot.png"), findsNothing);
    // Nothing left to show: the composer collapses back to its resting pill.
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets("image-only context-menu paste stages an attachment", (tester) async {
    final attachment = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: null);
    when(imageClipboard.readImage).thenAnswer((_) async => _tinyPng);
    when(
      () => imagePicker.attachmentFromBytes(bytes: _tinyPng, filename: null),
    ).thenReturn(attachment);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    await enterTypingMode(tester);

    final textField = tester.widget<TextField>(find.byType(TextField));
    final editableTextState = tester.state<EditableTextState>(find.byType(EditableText));
    final toolbar = textField.contextMenuBuilder!(
      tester.element(find.byType(TextField)),
      editableTextState,
    ) as AdaptiveTextSelectionToolbar;
    final pasteItem = toolbar.buttonItems!.singleWhere((item) => item.type == ContextMenuButtonType.paste);

    pasteItem.onPressed!();
    await tester.pumpAndSettle();

    expect(semanticsWithLabel("Attached image"), findsOneWidget);
    verify(imageClipboard.readImage).called(1);
    verify(() => imagePicker.attachmentFromBytes(bytes: _tinyPng, filename: null)).called(1);
  });

  testWidgets("keyboard image paste stages an attachment without inserting text", (tester) async {
    final attachment = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: null);
    when(imageClipboard.readImage).thenAnswer((_) async => _tinyPng);
    when(
      () => imagePicker.attachmentFromBytes(bytes: _tinyPng, filename: null),
    ).thenReturn(attachment);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    await enterTypingMode(tester);

    final actionContext = tester.element(
      find.descendant(of: find.byType(EditableText), matching: find.byType(RawGestureDetector)).first,
    );
    Actions.invoke(actionContext, const PasteTextIntent(SelectionChangedCause.keyboard));
    await tester.pumpAndSettle();

    expect(semanticsWithLabel("Attached image"), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, isEmpty);
    verify(imageClipboard.readImage).called(1);
  });

  testWidgets("plain text paste still delegates to Flutter's text action", (tester) async {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "Clipboard.getData") return <String, Object>{"text": "pasted"};
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    await enterTypingMode(tester);
    await tester.enterText(find.byType(EditableText), "before after");
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    editableText.controller.selection = const TextSelection(baseOffset: 0, extentOffset: 6);

    final actionContext = tester.element(
      find.descendant(of: find.byType(EditableText), matching: find.byType(RawGestureDetector)).first,
    );
    Actions.invoke(actionContext, const PasteTextIntent(SelectionChangedCause.keyboard));
    await tester.pumpAndSettle();

    expect(editableText.controller.text, "pasted after");
    verify(imageClipboard.readImage).called(1);
    verifyNever(() => imagePicker.attachmentFromBytes(bytes: _tinyPng, filename: null));
  });

  testWidgets("an unsupported pasted image falls back to text paste", (tester) async {
    final bytes = Uint8List.fromList(const [0, 1, 2, 3, 4, 5, 6, 7]);
    when(imageClipboard.readImage).thenAnswer((_) async => bytes);
    when(
      () => imagePicker.attachmentFromBytes(bytes: bytes, filename: null),
    ).thenThrow(const UnsupportedAttachmentImageError());
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "Clipboard.getData") return <String, Object>{"text": "pasted"};
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    await enterTypingMode(tester);
    await tester.enterText(find.byType(EditableText), "before after");
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    editableText.controller.selection = const TextSelection(baseOffset: 0, extentOffset: 6);

    final actionContext = tester.element(
      find.descendant(of: find.byType(EditableText), matching: find.byType(RawGestureDetector)).first,
    );
    Actions.invoke(actionContext, const PasteTextIntent(SelectionChangedCause.keyboard));
    await tester.pumpAndSettle();

    expect(find.text("That image format isn't supported."), findsOneWidget);
    expect(editableText.controller.text, "pasted after");
  });

  testWidgets("delayed context-menu text fallback uses the original selection", (tester) async {
    final imageRead = Completer<Uint8List?>();
    when(imageClipboard.readImage).thenAnswer((_) => imageRead.future);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "Clipboard.getData") return <String, Object>{"text": "pasted"};
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    await enterTypingMode(tester);
    await tester.enterText(find.byType(EditableText), "before after");
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    editableText.controller.selection = const TextSelection(baseOffset: 0, extentOffset: 6);

    final textField = tester.widget<TextField>(find.byType(TextField));
    final editableTextState = tester.state<EditableTextState>(find.byType(EditableText));
    final toolbar = textField.contextMenuBuilder!(
      tester.element(find.byType(TextField)),
      editableTextState,
    ) as AdaptiveTextSelectionToolbar;
    final pasteItem = toolbar.buttonItems!.singleWhere((item) => item.type == ContextMenuButtonType.paste);

    pasteItem.onPressed!();
    editableText.controller.selection = TextSelection.collapsed(offset: editableText.controller.text.length);
    imageRead.complete(null);
    await tester.pumpAndSettle();

    expect(editableText.controller.text, "pasted after");
  });

  testWidgets("delayed text paste uses the selection from the original intent", (tester) async {
    final imageRead = Completer<Uint8List?>();
    when(imageClipboard.readImage).thenAnswer((_) => imageRead.future);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "Clipboard.getData") return <String, Object>{"text": "pasted"};
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    await enterTypingMode(tester);
    await tester.enterText(find.byType(EditableText), "before after");
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    editableText.controller.selection = const TextSelection(baseOffset: 0, extentOffset: 6);

    final actionContext = tester.element(
      find.descendant(of: find.byType(EditableText), matching: find.byType(RawGestureDetector)).first,
    );
    Actions.invoke(actionContext, const PasteTextIntent(SelectionChangedCause.keyboard));
    editableText.controller.selection = TextSelection.collapsed(offset: editableText.controller.text.length);
    imageRead.complete(null);
    await tester.pumpAndSettle();

    expect(editableText.controller.text, "pasted after");
  });

  testWidgets("a clipboard image settling after send is discarded", (tester) async {
    final imageRead = Completer<Uint8List?>();
    when(imageClipboard.readImage).thenAnswer((_) => imageRead.future);
    when(
      () => imagePicker.attachmentFromBytes(bytes: _tinyPng, filename: null),
    ).thenReturn(ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: null));
    when(
      () => cubit.sendMessage(
        text: any(named: "text"),
        command: any(named: "command"),
        inputMode: any(named: "inputMode"),
        attachments: any(named: "attachments"),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    await enterTypingMode(tester);
    await tester.enterText(find.byType(EditableText), "send now");
    await tester.pump();

    final actionContext = tester.element(
      find.descendant(of: find.byType(EditableText), matching: find.byType(RawGestureDetector)).first,
    );
    Actions.invoke(actionContext, const PasteTextIntent(SelectionChangedCause.keyboard));
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();
    imageRead.complete(_tinyPng);
    await tester.pumpAndSettle();

    expect(semanticsWithLabel("Attached image"), findsNothing);
    verifyNever(() => imagePicker.attachmentFromBytes(bytes: _tinyPng, filename: null));
  });

  testWidgets("a clipboard image is discarded after attachment support toggles", (tester) async {
    final stateController = StreamController<SessionDetailState>();
    addTearDown(stateController.close);
    final opencodeState = _loadedState(pendingQuestions: const [], pendingPermissions: const []);
    when(() => cubit.state).thenReturn(opencodeState);
    whenListen(cubit, stateController.stream, initialState: opencodeState);
    final imageRead = Completer<Uint8List?>();
    when(imageClipboard.readImage).thenAnswer((_) => imageRead.future);
    when(
      () => imagePicker.attachmentFromBytes(bytes: _tinyPng, filename: null),
    ).thenReturn(ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: null));

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    await enterTypingMode(tester);

    final actionContext = tester.element(
      find.descendant(of: find.byType(EditableText), matching: find.byType(RawGestureDetector)).first,
    );
    Actions.invoke(actionContext, const PasteTextIntent(SelectionChangedCause.keyboard));
    stateController.add(opencodeState.copyWith(supportsPromptAttachments: false));
    await tester.pumpAndSettle();
    stateController.add(opencodeState);
    await tester.pumpAndSettle();
    imageRead.complete(_tinyPng);
    await tester.pumpAndSettle();

    expect(semanticsWithLabel("Attached image"), findsNothing);
    verifyNever(() => imagePicker.attachmentFromBytes(bytes: _tinyPng, filename: null));
  });

  testWidgets("accordion offers no attach action when the plugin declares no support", (tester) async {
    final state = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      pluginId: "opencode",
      supportsPromptAttachments: false,
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();

    expect(find.byIcon(TablerRegular.photo), findsNothing);
    // The accordion still opens for its other action.
    expect(find.byIcon(TablerRegular.slash), findsOneWidget);
  });

  testWidgets("staged attachment survives unresolved support but cannot send", (tester) async {
    final attachment = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: "screenshot.png");
    when(imagePicker.pickImage).thenAnswer((_) async => attachment);
    when(
      () => cubit.sendMessage(
        text: any(named: "text"),
        command: any(named: "command"),
        inputMode: any(named: "inputMode"),
        attachments: any(named: "attachments"),
      ),
    ).thenAnswer((_) async {});
    final states = StreamController<SessionDetailState>.broadcast();
    addTearDown(states.close);
    final supported = _loadedState(
      pendingQuestions: const [],
      pendingPermissions: const [],
      pluginId: "codex",
      supportsPromptAttachments: true,
    );
    whenListen(cubit, states.stream, initialState: supported);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.photo));
    await tester.pumpAndSettle();

    states.add(supported.copyWith(supportsPromptAttachments: null));
    await tester.pumpAndSettle();
    expect(semanticsWithLabel("screenshot.png"), findsOneWidget);
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();
    verifyNever(
      () => cubit.sendMessage(
        text: any(named: "text"),
        command: any(named: "command"),
        inputMode: any(named: "inputMode"),
        attachments: any(named: "attachments"),
      ),
    );

    states.add(supported.copyWith(supportsPromptAttachments: false));
    await tester.pumpAndSettle();
    expect(semanticsWithLabel("screenshot.png"), findsNothing);
  });

  testWidgets("send includes the staged attachment and clears the strip", (tester) async {
    final attachment = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: "screenshot.png");
    when(imagePicker.pickImage).thenAnswer((_) async => attachment);
    when(
      () => cubit.sendMessage(
        text: any(named: "text"),
        command: any(named: "command"),
        inputMode: any(named: "inputMode"),
        attachments: any(named: "attachments"),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.photo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), "with image");
    await tester.pump();
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();

    verify(
      () => cubit.sendMessage(
        text: "with image",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: [attachment],
      ),
    ).called(1);
    await tester.pumpAndSettle();
    expect(semanticsWithLabel("screenshot.png"), findsNothing);
  });

  testWidgets("an attachment alone is sendable", (tester) async {
    final attachment = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: null);
    when(imagePicker.pickImage).thenAnswer((_) async => attachment);
    when(
      () => cubit.sendMessage(
        text: any(named: "text"),
        command: any(named: "command"),
        inputMode: any(named: "inputMode"),
        attachments: any(named: "attachments"),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.photo));
    await tester.pumpAndSettle();

    expect(semanticsWithLabel("Attached image"), findsOneWidget);
    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();

    verify(
      () => cubit.sendMessage(
        text: "",
        command: null,
        inputMode: ComposerInputMode.typed,
        attachments: [attachment],
      ),
    ).called(1);
  });

  testWidgets("an image pushing the strip past the per-message budget is rejected", (tester) async {
    // Two picks: a tiny renderable image, then one whose size alone nearly
    // fills the outbound composer budget — staging it would push the combined
    // strip past the limit, so it is refused with a notice instead.
    final huge = Uint8List(maxComposerPromptAttachmentBytes - 32);
    huge.setAll(0, const [0xFF, 0xD8, 0xFF]);
    final answers = <ComposerAttachment>[
      ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: "small.png"),
      ComposerAttachment(mime: "image/jpeg", bytes: huge, filename: "huge.jpg"),
    ];
    when(imagePicker.pickImage).thenAnswer((_) async => answers.removeAt(0));

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.photo));
    await tester.pumpAndSettle();
    expect(semanticsWithLabel("small.png"), findsOneWidget);

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.photo));
    await tester.pumpAndSettle();

    expect(find.text("Attached images are limited to 50 MB per message."), findsOneWidget);
    // The refused image was never staged; the first one is untouched.
    expect(semanticsWithLabel("small.png"), findsOneWidget);
    expect(semanticsWithLabel("huge.jpg"), findsNothing);
  });

  testWidgets("an oversized image is rejected with a notice", (tester) async {
    when(imagePicker.pickImage).thenAnswer((_) async => throw const AttachmentTooLargeError());

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.photo));
    await tester.pumpAndSettle();

    expect(find.text("That image is too large to attach."), findsOneWidget);
    // Nothing was staged, so the composer stays in its resting pill.
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets("send is refused while both a command and attachments are staged", (tester) async {
    final attachment = ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: "screenshot.png");
    when(imagePicker.pickImage).thenAnswer((_) async => attachment);
    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      stagedCommand: const CommandInfo(
        name: "review",
        template: null,
        hints: null,
        description: null,
        agent: null,
        model: null,
        provider: null,
        source: null,
        subtask: null,
      ),
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.photo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pumpAndSettle();

    // The bridge's command paths carry only text, so the send is refused and
    // both the command chip and the image stay staged.
    expect(find.text("Images can't be sent with slash commands."), findsOneWidget);
    expect(semanticsWithLabel("screenshot.png"), findsOneWidget);
    verifyNever(
      () => cubit.sendMessage(
        text: any(named: "text"),
        command: any(named: "command"),
        inputMode: any(named: "inputMode"),
        attachments: any(named: "attachments"),
      ),
    );
  });

  testWidgets("a queued attachment-only submission shows its thumbnail and image count", (tester) async {
    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      queuedMessages: [
        QueuedSessionSubmission.text(
          promptId: "prompt-1",
          text: "",
          inputMode: ComposerInputMode.typed,
          attachments: [
            ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: null),
          ],
          agent: "coder",
          agentModel: null,
        ),
      ],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.text("1 image"), findsOneWidget);
    expect(find.descendant(of: find.byType(QueuedMessageBubble), matching: find.byType(Image)), findsOneWidget);
  });

  testWidgets("a queued submission renders inline with the transcript", (tester) async {
    final submission = QueuedSessionSubmission.text(
      promptId: "prompt-1",
      text: "Please **review** `main.dart`",
      inputMode: ComposerInputMode.typed,
      attachments: [
        ComposerAttachment(mime: "image/png", bytes: _tinyPng, filename: "reference.png"),
      ],
      agent: "coder",
      agentModel: null,
    );
    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      queuedMessages: [submission],
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(SessionDetailMessageList),
        matching: find.byType(QueuedMessageBubble),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byType(QueuedMessageBubble),
        matching: find.byWidgetPredicate(
          (widget) => widget is ListView && widget.reverse,
        ),
      ),
      findsOneWidget,
    );
    final bubble = tester.widget<UserMessageBubble>(
      find.descendant(of: find.byType(QueuedMessageBubble), matching: find.byType(UserMessageBubble)),
    );
    expect(bubble.outlined, isTrue);
    expect(find.descendant(of: find.byType(QueuedMessageBubble), matching: find.byType(MarkdownBody)), findsOneWidget);
    expect(find.descendant(of: find.byType(QueuedMessageBubble), matching: find.byType(Image)), findsOneWidget);
    expect(find.text("Queued"), findsOneWidget);
    expect(find.text("Cancel"), findsOneWidget);
    expect(tester.getSize(find.widgetWithText(TextButton, "Cancel")).height, 44);

    await tester.tap(find.text("Cancel"));
    verify(() => cubit.cancelQueuedMessage(0)).called(1);
  });

  testWidgets("the same inline queued bubble becomes sending in place", (tester) async {
    const submission = QueuedSessionSubmission.text(
      promptId: "prompt-1",
      text: "Cold-start prompt",
      inputMode: ComposerInputMode.typed,
      attachments: [],
      agent: "coder",
      agentModel: null,
    );
    const followingSubmission = QueuedSessionSubmission.text(
      promptId: "prompt-2",
      text: "Next prompt",
      inputMode: ComposerInputMode.typed,
      attachments: [],
      agent: "coder",
      agentModel: null,
    );
    var state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      queuedMessages: const [submission, followingSubmission],
    );
    final states = StreamController<SessionDetailState>.broadcast();
    addTearDown(states.close);
    when(() => cubit.state).thenAnswer((_) => state);
    when(() => cubit.stream).thenAnswer((_) => states.stream);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    final submissionFinder = find.byWidgetPredicate(
      (widget) => widget is QueuedMessageBubble && widget.key == const ValueKey("session-detail-prompt-prompt-1"),
    );
    final before = tester.element(submissionFinder);
    expect(
      find.descendant(of: find.byType(SessionDetailMessageList), matching: submissionFinder),
      findsOneWidget,
    );
    expect(
      tester
          .widget<UserMessageBubble>(
            find.descendant(of: submissionFinder, matching: find.byType(UserMessageBubble)),
          )
          .outlined,
      isTrue,
    );
    state = state.copyWith(queuedMessages: const [followingSubmission], sendingSubmission: submission);
    states.add(state);
    await tester.idle();
    await tester.pump();

    expect(identical(tester.element(submissionFinder), before), isTrue);
    // The outgoing status rail cross-fades out; settle it before counting.
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<UserMessageBubble>(
            find.descendant(of: submissionFinder, matching: find.byType(UserMessageBubble)),
          )
          .outlined,
      isFalse,
    );
    expect(find.text("Sending"), findsOneWidget);
    expect(find.text("Cancel"), findsOneWidget);
    expect(find.descendant(of: submissionFinder, matching: find.text("Cancel")), findsNothing);
  });

  testWidgets("reduced motion swaps queued feedback immediately", (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    const submission = QueuedSessionSubmission.text(
      promptId: "prompt-1",
      text: "Cold-start prompt",
      inputMode: ComposerInputMode.typed,
      attachments: [],
      agent: "coder",
      agentModel: null,
    );
    var state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      queuedMessages: const [submission],
    );
    final states = StreamController<SessionDetailState>.broadcast();
    addTearDown(states.close);
    when(() => cubit.state).thenAnswer((_) => state);
    when(() => cubit.stream).thenAnswer((_) => states.stream);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pumpAndSettle();

    state = state.copyWith(queuedMessages: const [], sendingSubmission: submission);
    states.add(state);
    await tester.idle();
    await tester.pump();

    expect(find.text("Cancel"), findsNothing);
    expect(find.text("Sending"), findsOneWidget);
    expect(find.byType(PregoActivityIndicator), findsOneWidget);
  });

  testWidgets("an in-flight submission stays visible without a cancel action", (tester) async {
    final state = _loadedState(pendingQuestions: const [], pendingPermissions: const []).copyWith(
      sendingSubmission: const QueuedSessionSubmission.text(
        promptId: "prompt-1",
        text: "Cold-start prompt",
        inputMode: ComposerInputMode.typed,
        attachments: [],
        agent: "coder",
        agentModel: null,
      ),
    );
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);

    await tester.pumpWidget(_buildApp(cubit: cubit));
    await tester.pump();

    expect(find.text("Cold-start prompt"), findsOneWidget);
    expect(find.text("Sending"), findsOneWidget);
    expect(find.text("Cancel"), findsNothing);
  });
}
