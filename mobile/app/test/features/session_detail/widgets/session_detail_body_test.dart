import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/session_detail/widgets/session_detail_body.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";

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
            sessionId: "session-1",
            sessionTitle: "Session",
            readOnly: false,
          ),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

SessionDetailState _loadedState() {
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
    selectedVariant: const SessionVariant(id: "xhigh"),
  );
}

void main() {
  late MockSessionDetailCubit cubit;
  late MockVoiceTranscriptionService voiceTranscriptionService;

  setUp(() async {
    await GetIt.instance.reset();
    cubit = MockSessionDetailCubit();
    voiceTranscriptionService = MockVoiceTranscriptionService();

    final state = _loadedState();
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<SessionDetailState>.empty(), initialState: state);
    when(() => cubit.questionStream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.permissionStream).thenAnswer((_) => const Stream.empty());

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

    await tester.tap(find.widgetWithText(OutlinedButton, "xhigh"));
    await tester.pumpAndSettle();

    expect(find.text("Variant"), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, "xhigh"));
    await tester.pumpAndSettle();

    verify(() => cubit.selectVariant(const SessionVariant(id: "xhigh"))).called(1);
  });
}
