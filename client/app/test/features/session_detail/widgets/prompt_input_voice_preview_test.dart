import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/media/composer_image_picker.dart";
import "package:sesori_mobile/features/session_detail/widgets/prompt_input.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/test_helpers.dart";

class MockVoiceTranscriptionService() extends Mock implements VoiceTranscriptionService;

class MockVoiceTranscriptionSession() extends Mock implements VoiceTranscriptionSession;

class MockComposerImagePicker() extends Mock implements ComposerImagePicker;

class MockImageClipboard() extends Mock implements ImageClipboard;

class const _BuildCounter({required final VoidCallback onBuild}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    onBuild();
    return const SizedBox.shrink();
  }
}

const _emptyPreview = VoiceTranscriptionPreview(confirmedText: "", provisionalText: "");

void main() {
  late MockVoiceTranscriptionService voiceTranscriptionService;
  late MockVoiceTranscriptionSession voiceSession;
  late StreamController<VoiceTranscriptionPreview> previewController;
  late StreamController<void> maxDurationController;
  late ValueNotifier<PregoComposerSurfaceStyle> surfaceStyleController;
  late List<ComposerDraft> draftChanges;
  late int completedCount;

  setUp(() async {
    KeyboardVisibilityTesting.setVisibilityForTesting(false);
    await GetIt.instance.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );

    voiceTranscriptionService = MockVoiceTranscriptionService();
    voiceSession = MockVoiceTranscriptionSession();
    previewController = StreamController<VoiceTranscriptionPreview>.broadcast();
    maxDurationController = StreamController<void>.broadcast();
    surfaceStyleController = ValueNotifier(PregoComposerSurfaceStyle.subtle);
    draftChanges = [];
    completedCount = 0;

    when(() => voiceTranscriptionService.currentPreview(session: voiceSession)).thenReturn(_emptyPreview);
    when(() => voiceTranscriptionService.previewStream(session: voiceSession))
        .thenAnswer((_) => previewController.stream);
    when(() => voiceTranscriptionService.maxDurationReachedStream(session: voiceSession)).thenAnswer(
      (_) => maxDurationController.stream,
    );
    when(
      () => voiceTranscriptionService.realtimeTerminalStream(session: voiceSession),
    ).thenAnswer((_) => const Stream.empty());
    when(() => voiceTranscriptionService.prewarm(session: voiceSession)).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream(session: voiceSession)).thenAnswer(
      (_) => const Stream<double>.empty(),
    );
    when(() => voiceTranscriptionService.cancel(session: voiceSession)).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.invalidate(session: voiceSession)).thenReturn(null);
    when(() => voiceTranscriptionService.close(session: voiceSession)).thenAnswer((_) async {});

    GetIt.instance.registerSingleton<ComposerImagePicker>(MockComposerImagePicker());
    final imageClipboard = MockImageClipboard();
    when(imageClipboard.readImage).thenAnswer((_) async => null);
    GetIt.instance.registerSingleton<ImageClipboard>(imageClipboard);
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    surfaceStyleController.dispose();
    await previewController.close();
    await maxDurationController.close();
    await GetIt.instance.reset();
  });

  Widget buildHarness({String draftIdentity = "draft-1", Widget? header}) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ChatInputModeCubit>(create: (_) => StubChatInputModeCubit()),
        BlocProvider<VoiceInputCubit>(
          create: (_) => VoiceInputCubit(service: voiceTranscriptionService, session: voiceSession),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PromptInput(
              projectId: "project-1",
              draftIdentity: draftIdentity,
              restorationKey: null,
              initialDraft: ComposerDraft.typed(text: ""),
              initialAttachments: const [],
              onInitialAttachmentsConsumed: () {},
              hasMessages: false,
              attachmentsSupported: true,
              isBusy: false,
              onSend: ({required draft, required command, required attachments}) {},
              onVoiceTranscriptionCompleted: () => completedCount++,
              onDraftChanged: draftChanges.add,
              onDraftCleared: () {},
              onAbort: () {},
              surfaceStyleController: surfaceStyleController,
              header: header,
              composerHeader: null,
              availableCommands: const [],
              stagedCommand: null,
              onCommandSelected: (_) {},
              onCommandCleared: () {},
            ),
          ),
        ),
      ),
    );
  }

  Future<TestGesture> startVoiceHold(WidgetTester tester) async {
    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 250));
    return gesture;
  }

  testWidgets("starts recording with project context and previews without draft mutation", (tester) async {
    final stopCompleter = Completer<String>();
    when(
      () => voiceTranscriptionService.start(session: voiceSession),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession))
        .thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 250));
    verify(() => voiceTranscriptionService.start(session: voiceSession)).called(1);

    previewController.add(const VoiceTranscriptionPreview(confirmedText: "stable ", provisionalText: "dra"));
    await tester.pump();
    expect(find.textContaining("stable", findRichText: true), findsOneWidget);
    expect(find.textContaining("dra", findRichText: true), findsOneWidget);
    expect(draftChanges, isEmpty);

    previewController.add(const VoiceTranscriptionPreview(confirmedText: "stable ", provisionalText: "draft"));
    await tester.pump();
    expect(find.textContaining("draft", findRichText: true), findsOneWidget);
    expect(draftChanges, isEmpty);

    await gesture.up();
    await tester.pump();
    stopCompleter.complete("stable draft");
    await tester.pumpAndSettle();

    expect(draftChanges.map((draft) => draft.text), ["stable draft"]);
    expect(completedCount, 1);
  });

  testWidgets("terminal event during startup preserves gesture ownership and limit notice", (tester) async {
    final startCompleter = Completer<void>();
    final terminalController = StreamController<VoiceRealtimeTerminalCause>.broadcast();
    addTearDown(terminalController.close);
    when(
      () => voiceTranscriptionService.realtimeTerminalStream(session: voiceSession),
    ).thenAnswer((_) => terminalController.stream);
    when(
      () => voiceTranscriptionService.start(session: voiceSession),
    ).thenAnswer((_) => startCompleter.future);
    when(
      () => voiceTranscriptionService.stopAndTranscribe(session: voiceSession),
    ).thenAnswer((_) async => "captured before limit");

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump();
    terminalController.add(VoiceRealtimeTerminalCause.limitReached);
    await tester.pump();
    startCompleter.complete();
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump();
    await gesture.up();

    expect(find.text("Recording limit reached (15 minutes)"), findsOneWidget);
    expect(draftChanges.map((draft) => draft.text), ["captured before limit"]);
    expect(completedCount, 1);
    verify(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession)).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets("preview live region announces only stable confirmed text", (tester) async {
    final stopCompleter = Completer<String>();
    when(
      () => voiceTranscriptionService.start(session: voiceSession),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession))
        .thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    final gesture = await startVoiceHold(tester);
    previewController.add(const VoiceTranscriptionPreview(confirmedText: "stable ", provisionalText: "draft"));
    await tester.pump();

    expect(find.textContaining("draft", findRichText: true), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == "stable"),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && (widget.properties.label ?? "").contains("draft"),
      ),
      findsNothing,
    );

    await gesture.up();
    await tester.pump();
    stopCompleter.complete("stable draft");
    await tester.pumpAndSettle();
  });

  testWidgets("preview updates leave stable composer siblings unrebuilt", (tester) async {
    final stopCompleter = Completer<String>();
    var headerBuilds = 0;
    when(
      () => voiceTranscriptionService.start(session: voiceSession),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession))
        .thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(
      buildHarness(
        header: _BuildCounter(onBuild: () => headerBuilds++),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await startVoiceHold(tester);
    final buildsAfterRecordingStart = headerBuilds;
    previewController.add(const VoiceTranscriptionPreview(confirmedText: "stable ", provisionalText: "dra"));
    await tester.pump();
    previewController.add(const VoiceTranscriptionPreview(confirmedText: "stable ", provisionalText: "draft"));
    await tester.pump();

    expect(headerBuilds, buildsAfterRecordingStart);
    expect(find.textContaining("stable", findRichText: true), findsOneWidget);
    expect(find.textContaining("draft", findRichText: true), findsOneWidget);
    expect(draftChanges, isEmpty);

    await gesture.up();
    await tester.pump();
    stopCompleter.complete("stable draft");
    await tester.pumpAndSettle();
  });

  testWidgets("partial realtime failure commits confirmed text once without success analytics", (tester) async {
    when(
      () => voiceTranscriptionService.start(session: voiceSession),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession)).thenThrow(
      VoiceRealtimePartialTranscriptionError(
        confirmedText: "captured text",
        failure: VoiceTranscriptionError.realtimeInterrupted(
          innerError: Exception("closed"),
          innerStackTrace: null,
        ),
      ),
    );

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 250));
    previewController.add(
      const VoiceTranscriptionPreview(confirmedText: "captured text", provisionalText: " discarded"),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(draftChanges.map((draft) => draft.text), ["captured text"]);
    expect(find.textContaining("discarded", findRichText: true), findsNothing);
    expect(completedCount, 0);
    expect(find.text("Voice connection was interrupted. Try again."), findsOneWidget);
  });

  testWidgets("partial realtime failures show provider-neutral typed messages", (tester) async {
    final scenarios = <({String name, VoiceTranscriptionError failure, String message})>[
      (
        name: "quota",
        failure: VoiceTranscriptionError.realtimeQuota(
          innerError: null,
          innerStackTrace: null,
        ),
        message: "Voice input quota reached. Try again later.",
      ),
      (
        name: "capacity",
        failure: VoiceTranscriptionError.realtimeTemporaryUnavailable(
          innerError: null,
          innerStackTrace: null,
        ),
        message: "Voice input is temporarily unavailable. Try again in a moment.",
      ),
      (
        name: "timeout",
        failure: VoiceTranscriptionError.realtimeTemporaryUnavailable(
          innerError: TimeoutException("finish"),
          innerStackTrace: null,
        ),
        message: "Voice input is temporarily unavailable. Try again in a moment.",
      ),
      (
        name: "transport",
        failure: VoiceTranscriptionError.realtimeInterrupted(
          innerError: Exception("closed"),
          innerStackTrace: null,
        ),
        message: "Voice connection was interrupted. Try again.",
      ),
      (
        name: "protocol",
        failure: VoiceTranscriptionError.realtimeContract(
          reason: "unsupported protocol",
          innerError: const FormatException("unsupported protocol"),
          innerStackTrace: null,
        ),
        message: "Voice input needs an app update. Update Sesori and try again.",
      ),
      (
        name: "contract",
        failure: VoiceTranscriptionError.realtimeContract(
          reason: "bad frame",
          innerError: const FormatException("bad frame"),
          innerStackTrace: null,
        ),
        message: "Voice input needs an app update. Update Sesori and try again.",
      ),
    ];

    for (final scenario in scenarios) {
      draftChanges.clear();
      completedCount = 0;
      when(
        () => voiceTranscriptionService.start(session: voiceSession),
      ).thenAnswer((_) async {});
      when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession)).thenThrow(
        VoiceRealtimePartialTranscriptionError(
          confirmedText: "captured ${scenario.name}",
          failure: scenario.failure,
        ),
      );

      await tester.pumpWidget(buildHarness(draftIdentity: "partial-${scenario.name}"));
      await tester.pumpAndSettle();

      final gesture = await startVoiceHold(tester);
      previewController.add(
        VoiceTranscriptionPreview(confirmedText: "captured ${scenario.name}", provisionalText: " discarded"),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(draftChanges.map((draft) => draft.text), ["captured ${scenario.name}"]);
      expect(find.textContaining("discarded", findRichText: true), findsNothing);
      expect(completedCount, 0);
      expect(find.text(scenario.message), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets("start failures show typed messages instead of recording fallback", (tester) async {
    final scenarios = <({String name, VoiceTranscriptionError failure, String message})>[
      (
        name: "permission",
        failure: VoiceTranscriptionError.microphonePermissionDenied(
          innerError: VoiceCaptureError.permissionDenied(innerError: null),
        ),
        message: "Microphone permission is required for voice input",
      ),
      (
        name: "auth",
        failure: VoiceTranscriptionError.notAuthenticated(),
        message: "Sign in to use voice input",
      ),
      (
        name: "network",
        failure: VoiceTranscriptionError.networkError(),
        message: "Could not reach the server. Check your connection.",
      ),
      (
        name: "contract",
        failure: VoiceTranscriptionError.contractFailure(
          reason: "bad capabilities",
          innerError: const FormatException("bad capabilities"),
          innerStackTrace: null,
        ),
        message: "Voice input needs an app update. Update Sesori and try again.",
      ),
    ];

    for (final scenario in scenarios) {
      draftChanges.clear();
      when(
        () => voiceTranscriptionService.start(session: voiceSession),
      ).thenThrow(scenario.failure);
      when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession)).thenAnswer((_) async => "");

      await tester.pumpWidget(buildHarness(draftIdentity: "start-${scenario.name}"));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(draftChanges, isEmpty);
      expect(find.text(scenario.message), findsOneWidget);
      expect(find.text("Recording failed. Please try again."), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets("cancelled interaction ignores stale preview and terminal events", (tester) async {
    final stopCompleter = Completer<String>();
    when(
      () => voiceTranscriptionService.start(session: voiceSession),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession))
        .thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 250));
    previewController.add(const VoiceTranscriptionPreview(confirmedText: "before cancel", provisionalText: " live"));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    await tester.tap(find.byTooltip("Cancel transcription"));
    await tester.pumpAndSettle();
    previewController.add(const VoiceTranscriptionPreview(confirmedText: "stale text", provisionalText: " stale"));
    stopCompleter.complete("stale terminal");
    await tester.pumpAndSettle();

    expect(draftChanges, isEmpty);
    expect(find.textContaining("stale", findRichText: true), findsNothing);
    expect(completedCount, 0);
  });

  testWidgets("draft identity reuse cancels start in flight and ignores stale preview", (tester) async {
    final startCompleter = Completer<void>();
    when(
      () => voiceTranscriptionService.start(session: voiceSession),
    ).thenAnswer((_) => startCompleter.future);
    when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession))
        .thenAnswer((_) async => "stale terminal");

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump();
    await tester.pumpWidget(buildHarness(draftIdentity: "draft-2"));
    await tester.pump();

    verify(() => voiceTranscriptionService.cancel(session: voiceSession)).called(1);
    startCompleter.complete();
    await tester.pumpAndSettle();
    previewController.add(const VoiceTranscriptionPreview(confirmedText: "stale text", provisionalText: " stale"));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(draftChanges, isEmpty);
    expect(find.textContaining("stale", findRichText: true), findsNothing);
    expect(completedCount, 0);
  });

  testWidgets("draft identity reuse orphans in-flight terminal transcript", (tester) async {
    final stopCompleter = Completer<String>();
    when(
      () => voiceTranscriptionService.start(session: voiceSession),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe(session: voiceSession))
        .thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    final gesture = await startVoiceHold(tester);
    await gesture.up();
    await tester.pump();
    await tester.pumpWidget(buildHarness(draftIdentity: "draft-2"));
    await tester.pump();

    verify(() => voiceTranscriptionService.cancel(session: voiceSession)).called(1);
    stopCompleter.complete("stale terminal");
    await tester.pumpAndSettle();

    expect(draftChanges, isEmpty);
    expect(find.textContaining("stale", findRichText: true), findsNothing);
    expect(completedCount, 0);
  });
}
