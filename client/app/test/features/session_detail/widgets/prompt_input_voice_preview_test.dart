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
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/session_detail/widgets/prompt_input.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/test_helpers.dart";

class MockVoiceTranscriptionService() extends Mock implements VoiceTranscriptionService;

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
    previewController = StreamController<VoiceTranscriptionPreview>.broadcast();
    maxDurationController = StreamController<void>.broadcast();
    surfaceStyleController = ValueNotifier(PregoComposerSurfaceStyle.subtle);
    draftChanges = [];
    completedCount = 0;

    when(() => voiceTranscriptionService.currentPreview).thenReturn(_emptyPreview);
    when(() => voiceTranscriptionService.previewStream).thenAnswer((_) => previewController.stream);
    when(() => voiceTranscriptionService.onMaxDurationReached).thenAnswer((_) => maxDurationController.stream);
    when(() => voiceTranscriptionService.prewarmRecording()).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(() => voiceTranscriptionService.cancelRecording()).thenAnswer((_) async {});
    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);

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
    return BlocProvider<ChatInputModeCubit>(
      create: (_) => StubChatInputModeCubit(),
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
      () => voiceTranscriptionService.startRecording(projectId: "project-1"),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump(const Duration(milliseconds: 250));
    verify(() => voiceTranscriptionService.startRecording(projectId: "project-1")).called(1);

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

  testWidgets("preview live region announces only stable confirmed text", (tester) async {
    final stopCompleter = Completer<String>();
    when(
      () => voiceTranscriptionService.startRecording(projectId: "project-1"),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

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
      () => voiceTranscriptionService.startRecording(projectId: "project-1"),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

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
      () => voiceTranscriptionService.startRecording(projectId: "project-1"),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenThrow(
      VoiceRealtimePartialTranscriptionError(
        confirmedText: "captured text",
        failure: VoiceTranscriptionError.realtimeTransport(cause: null, retryable: true),
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
        failure: VoiceTranscriptionError.realtimeServer(code: RealtimeVoiceErrorCode.quotaExhausted),
        message: "Voice input quota reached. Try again later.",
      ),
      (
        name: "capacity",
        failure: VoiceTranscriptionError.realtimeServer(code: RealtimeVoiceErrorCode.providerCapacity),
        message: "Voice input is temporarily unavailable. Try again in a moment.",
      ),
      (
        name: "timeout",
        failure: VoiceTranscriptionError.realtimeTimeout(cause: TimeoutException("finish")),
        message: "Voice input is temporarily unavailable. Try again in a moment.",
      ),
      (
        name: "transport",
        failure: VoiceTranscriptionError.realtimeTransport(cause: null, retryable: true),
        message: "Voice connection was interrupted. Try again.",
      ),
      (
        name: "protocol",
        failure: VoiceTranscriptionError.realtimeServer(code: RealtimeVoiceErrorCode.unsupportedProtocol),
        message: "Voice input needs an app update. Update Sesori and try again.",
      ),
      (
        name: "contract",
        failure: VoiceTranscriptionError.realtimeContract(reason: "bad frame", cause: null),
        message: "Voice input needs an app update. Update Sesori and try again.",
      ),
    ];

    for (final scenario in scenarios) {
      draftChanges.clear();
      completedCount = 0;
      when(
        () => voiceTranscriptionService.startRecording(projectId: "project-1"),
      ).thenAnswer((_) async {});
      when(() => voiceTranscriptionService.stopAndTranscribe()).thenThrow(
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
        failure: VoiceTranscriptionError.microphonePermissionDenied(),
        message: "Microphone permission is required for voice input",
      ),
      (
        name: "auth",
        failure: VoiceTranscriptionError.notAuthenticated(cause: null),
        message: "Sign in to use voice input",
      ),
      (
        name: "network",
        failure: VoiceTranscriptionError.networkError(),
        message: "Could not reach the server. Check your connection.",
      ),
      (
        name: "contract",
        failure: VoiceTranscriptionError.contractFailure(reason: "bad capabilities", cause: null),
        message: "Voice input needs an app update. Update Sesori and try again.",
      ),
    ];

    for (final scenario in scenarios) {
      draftChanges.clear();
      when(
        () => voiceTranscriptionService.startRecording(projectId: "project-1"),
      ).thenThrow(scenario.failure);
      when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "");

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
      () => voiceTranscriptionService.startRecording(projectId: "project-1"),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

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
      () => voiceTranscriptionService.startRecording(projectId: "project-1"),
    ).thenAnswer((_) => startCompleter.future);
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) async => "stale terminal");

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text("Hold to talk")));
    await tester.pump();
    await tester.pumpWidget(buildHarness(draftIdentity: "draft-2"));
    await tester.pump();

    verify(() => voiceTranscriptionService.cancelRecording()).called(1);
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
      () => voiceTranscriptionService.startRecording(projectId: "project-1"),
    ).thenAnswer((_) async {});
    when(() => voiceTranscriptionService.stopAndTranscribe()).thenAnswer((_) => stopCompleter.future);

    await tester.pumpWidget(buildHarness());
    await tester.pumpAndSettle();

    final gesture = await startVoiceHold(tester);
    await gesture.up();
    await tester.pump();
    await tester.pumpWidget(buildHarness(draftIdentity: "draft-2"));
    await tester.pump();

    verify(() => voiceTranscriptionService.cancelRecording()).called(1);
    stopCompleter.complete("stale terminal");
    await tester.pumpAndSettle();

    expect(draftChanges, isEmpty);
    expect(find.textContaining("stale", findRichText: true), findsNothing);
    expect(completedCount, 0);
  });
}
