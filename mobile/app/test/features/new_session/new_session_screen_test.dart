import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

class MockVoiceTranscriptionService extends Mock implements VoiceTranscriptionService {}

AgentInfo _testAgent({required String name, required String description, String? variant}) {
  return AgentInfo(
    name: name,
    description: description,
    model: null,
    variant: variant,
    mode: AgentMode.primary,
  );
}

Widget _buildApp() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => const NewSessionScreen(projectId: "project-1"),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  late MockSessionService sessionService;
  late MockVoiceTranscriptionService voiceTranscriptionService;

  setUp(() async {
    await GetIt.instance.reset();
    sessionService = MockSessionService();
    voiceTranscriptionService = MockVoiceTranscriptionService();

    when(() => sessionService.listAgents()).thenAnswer(
      (_) async => ApiResponse.success(
        Agents(
          agents: [
            _testAgent(name: "coder", description: "A coding assistant", variant: null),
            _testAgent(name: "coder", description: "A coding assistant", variant: "xhigh"),
            _testAgent(name: "coder", description: "A coding assistant", variant: "low"),
            _testAgent(name: "reviewer", description: "A review assistant"),
          ],
        ),
      ),
    );
    when(() => sessionService.listProviders()).thenAnswer(
      (_) async => ApiResponse.success(testProviderListResponse()),
    );
    when(() => sessionService.listCommands(projectId: any(named: "projectId"))).thenAnswer(
      (_) async => ApiResponse.success(const CommandListResponse(items: [])),
    );

    final maxDurationReached = StreamController<void>.broadcast();
    addTearDown(maxDurationReached.close);
    when(() => voiceTranscriptionService.onMaxDurationReached).thenAnswer((_) => maxDurationReached.stream);

    GetIt.instance.registerSingleton<SessionService>(sessionService);
    GetIt.instance.registerSingleton<AgentVariantOptionsBuilder>(const AgentVariantOptionsBuilder());
    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets("shows variant picker when selected agent has multiple variants", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, "Default"), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, "Default"));
    await tester.pumpAndSettle();

    expect(find.text("Variant"), findsOneWidget);
    expect(find.text("Default"), findsWidgets);
    expect(find.text("low"), findsOneWidget);
    expect(find.text("xhigh"), findsOneWidget);

    await tester.tap(find.text("xhigh"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, "xhigh"), findsOneWidget);
  });

  testWidgets("resets selected variant after changing agent", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, "Default"));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, "xhigh"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, "xhigh"), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, "coder"));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, "reviewer"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, "reviewer"), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, "xhigh"), findsNothing);
    expect(find.widgetWithText(OutlinedButton, "Default"), findsNothing);
  });
}
