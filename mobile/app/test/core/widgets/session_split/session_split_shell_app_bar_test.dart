import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_shell.dart";
import "package:sesori_mobile/features/session_detail/widgets/session_detail_body.dart";
import "package:sesori_mobile/features/session_diffs/session_diffs_body.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../../helpers/test_helpers.dart";

class MockSessionDetailCubit extends MockCubit<SessionDetailState> implements SessionDetailCubit {}

class MockDiffCubit extends MockCubit<DiffState> implements DiffCubit {}

class MockVoiceTranscriptionService extends Mock implements VoiceTranscriptionService {}

Widget _buildWideShell({required Widget detail}) {
  return MaterialApp(
    theme: ThemeData(extensions: [ZyraDesignSystem.light]),
    darkTheme: ThemeData(extensions: [ZyraDesignSystem.dark]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SessionSplitShell(
      projectId: "project-1",
      selectedSessionId: "session-1",
      routeKind: SessionSplitRouteKind.detail,
      list: const SizedBox(key: Key("test-list")),
      detail: detail,
    ),
  );
}

SessionDetailState _loadedDetailState() {
  final provider = testProviderListResponse().items.first;
  return SessionDetailState.loaded(
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

void main() {
  setUpAll(registerAllFallbackValues);

  group("SessionSplitShell wide detail app bar", () {
    late MockSessionDetailCubit cubit;
    late MockVoiceTranscriptionService voiceService;

    setUp(() async {
      await GetIt.instance.reset();
      cubit = MockSessionDetailCubit();
      voiceService = MockVoiceTranscriptionService();

      final state = _loadedDetailState();
      when(() => cubit.state).thenReturn(state);
      whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);
      when(() => cubit.questionStream).thenAnswer((_) => const Stream.empty());
      when(() => cubit.permissionStream).thenAnswer((_) => const Stream.empty());

      final maxDurationReached = StreamController<void>.broadcast();
      addTearDown(maxDurationReached.close);
      when(() => voiceService.onMaxDurationReached).thenAnswer((_) => maxDurationReached.stream);

      GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceService);
    });

    tearDown(() async {
      await GetIt.instance.reset();
    });

    testWidgets("shows exactly one app bar in right panel for detail body", (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildWideShell(
          detail: BlocProvider<SessionDetailCubit>.value(
            value: cubit,
            child: const SessionDetailBody(
              projectId: "project-1",
              sessionId: "session-1",
              sessionTitle: "Session",
              readOnly: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rightPane = find.byKey(const Key("session-split-right-pane"));
      final appBarsInRightPane = find.descendant(of: rightPane, matching: find.byType(AppBar));
      expect(appBarsInRightPane, findsOneWidget);
    });
  });

  group("SessionSplitShell wide diffs app bar", () {
    late MockDiffCubit cubit;

    setUp(() {
      cubit = MockDiffCubit();
      when(() => cubit.state).thenReturn(const DiffStateLoaded(files: []));
      whenListen(cubit, const Stream<DiffState>.empty(), initialState: const DiffStateLoaded(files: []));
    });

    testWidgets("shows exactly one app bar in right panel for diffs body", (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildWideShell(
          detail: BlocProvider<DiffCubit>.value(
            value: cubit,
            child: const SessionDiffsBody(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rightPane = find.byKey(const Key("session-split-right-pane"));
      final appBarsInRightPane = find.descendant(of: rightPane, matching: find.byType(AppBar));
      expect(appBarsInRightPane, findsOneWidget);
    });

    testWidgets("diffs app bar title shows file changes text", (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildWideShell(
          detail: BlocProvider<DiffCubit>.value(
            value: cubit,
            child: const SessionDiffsBody(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rightPane = find.byKey(const Key("session-split-right-pane"));
      // The AppBar title should contain "File Changes" localized text
      expect(find.descendant(of: rightPane, matching: find.text("File Changes")), findsOneWidget);
    });
  });
}
