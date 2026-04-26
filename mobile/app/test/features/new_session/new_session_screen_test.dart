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

AgentInfo _testAgent({required String name, required String description, required String? variant}) {
  return AgentInfo(
    name: name,
    description: description,
    model: AgentModel(providerID: "anthropic", modelID: "claude-3-5-sonnet", variant: variant),
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
            _testAgent(name: "coder", description: "A coding assistant", variant: "xhigh"),
            _testAgent(name: "reviewer", description: "A review assistant", variant: null),
          ],
        ),
      ),
    );
    when(() => sessionService.listProviders(projectId: any(named: "projectId"))).thenAnswer(
      (_) async => ApiResponse.success(testProviderListResponse()),
    );
    when(() => sessionService.listCommands(projectId: any(named: "projectId"))).thenAnswer(
      (_) async => ApiResponse.success(const CommandListResponse(items: [])),
    );

    final maxDurationReached = StreamController<void>.broadcast();
    addTearDown(maxDurationReached.close);
    when(() => voiceTranscriptionService.onMaxDurationReached).thenAnswer((_) => maxDurationReached.stream);

    GetIt.instance.registerSingleton<SessionService>(sessionService);
    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voiceTranscriptionService);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets("shows variant picker when selected agent has a variant", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, "xhigh"), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, "xhigh"));
    await tester.pumpAndSettle();

    expect(find.text("Variant"), findsOneWidget);
    expect(find.text("Default"), findsWidgets);
    expect(find.widgetWithText(ListTile, "xhigh"), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, "xhigh"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, "xhigh"), findsOneWidget);
  });

  testWidgets("selecting a different variant updates the displayed variant", (tester) async {
    when(() => sessionService.listProviders(projectId: any(named: "projectId"))).thenAnswer(
      (_) async => ApiResponse.success(
        const ProviderListResponse(
          connectedOnly: false,
          items: [
            ProviderInfo(
              id: "anthropic",
              name: "Anthropic",
              defaultModelID: "claude-3-5-sonnet",
              models: {
                "claude-3-5-sonnet": ProviderModel(
                  id: "claude-3-5-sonnet",
                  providerID: "anthropic",
                  name: "Claude 3.5 Sonnet",
                  variants: ["xhigh", "low"],
                  family: null,
                  releaseDate: null,
                ),
              },
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Initially shows the agent's default variant.
    expect(find.widgetWithText(OutlinedButton, "xhigh"), findsOneWidget);

    // Open variant picker.
    await tester.tap(find.widgetWithText(OutlinedButton, "xhigh"));
    await tester.pumpAndSettle();

    // Select a different variant.
    await tester.tap(find.widgetWithText(ListTile, "low"));
    await tester.pumpAndSettle();

    // The UI should now reflect the newly selected variant.
    expect(find.widgetWithText(OutlinedButton, "low"), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, "xhigh"), findsNothing);
  });

  testWidgets("selecting Default clears the displayed variant", (tester) async {
    when(() => sessionService.listProviders(projectId: any(named: "projectId"))).thenAnswer(
      (_) async => ApiResponse.success(
        const ProviderListResponse(
          connectedOnly: false,
          items: [
            ProviderInfo(
              id: "anthropic",
              name: "Anthropic",
              defaultModelID: "claude-3-5-sonnet",
              models: {
                "claude-3-5-sonnet": ProviderModel(
                  id: "claude-3-5-sonnet",
                  providerID: "anthropic",
                  name: "Claude 3.5 Sonnet",
                  variants: ["xhigh", "low"],
                  family: null,
                  releaseDate: null,
                ),
              },
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    // Initially shows the agent's default variant.
    expect(find.widgetWithText(OutlinedButton, "xhigh"), findsOneWidget);

    // Open variant picker.
    await tester.tap(find.widgetWithText(OutlinedButton, "xhigh"));
    await tester.pumpAndSettle();

    // Select Default (null variant).
    await tester.tap(find.widgetWithText(ListTile, "Default"));
    await tester.pumpAndSettle();

    // The UI should now show "Default".
    expect(find.widgetWithText(OutlinedButton, "Default"), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, "xhigh"), findsNothing);
  });

  testWidgets("preserves selectedAgentModel variant when changing agent", (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, "xhigh"));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, "xhigh"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, "xhigh"), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, "coder"));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, "reviewer"));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, "reviewer"), findsOneWidget);
    // Changing the agent seeds the variant from the agent's default.
    // Reviewer has variant: null, so the button shows "Default".
    expect(find.widgetWithText(OutlinedButton, "Default"), findsOneWidget);
  });
}
