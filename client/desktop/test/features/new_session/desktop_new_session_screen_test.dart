import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop/features/new_session/desktop_new_session_screen.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockNewSessionCubit() extends MockCubit<NewSessionState> implements NewSessionCubit;

class _MockChatInputModeCubit() extends MockCubit<ChatInputMode> implements ChatInputModeCubit;

class _MockPluginManagementService() extends Mock implements PluginManagementService;
class _MockCatalogRescanService() extends Mock implements CatalogRescanService;
class _MockUrlLauncher() extends Mock implements UrlLauncher;

const _state = NewSessionState.composing(
  config: NewSessionComposeConfig(
    availablePlugins: [],
    selectedPlugin: null,
    options: NewSessionOptionsLoadState.unsupported(),
    backendScope: NewSessionBackendScope.verified(bridgeId: null),
    isPluginDiscoveryInFlight: false,
    projectWorktreeCapability: NewSessionProjectWorktreeCapability.supported,
  ),
  phase: NewSessionPhase.idle(),
);

void main() {
  testWidgets("desktop new session stays text-first with a persisted voice-first preference", (tester) async {
    final newSessionCubit = _MockNewSessionCubit();
    final inputModeCubit = _MockChatInputModeCubit();
    when(() => newSessionCubit.state).thenReturn(_state);
    whenListen(newSessionCubit, const Stream<NewSessionState>.empty(), initialState: _state);
    when(() => newSessionCubit.needsHarnessDiscovery).thenReturn(false);
    when(() => newSessionCubit.hasNoHarnesses).thenReturn(false);
    when(() => newSessionCubit.canCreateSession).thenReturn(true);
    when(() => newSessionCubit.composerDraft).thenReturn(ComposerDraft.typed(text: ""));
    when(() => inputModeCubit.state).thenReturn(ChatInputMode.voiceFirst);
    whenListen(inputModeCubit, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.voiceFirst);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<NewSessionCubit>.value(value: newSessionCubit),
          BlocProvider<ChatInputModeCubit>.value(value: inputModeCubit),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DesktopNewSessionView(
            projectId: "project-1",
            projectName: "Sesori",
            onBack: () {},
            onOpenHarnessSettings: () {},
            onSessionCreated: ({required session}) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text("New session"), findsOneWidget);
    expect(find.text("Dedicated workspace"), findsOneWidget);
    expect(find.text("Ask anything..."), findsOneWidget);
    expect(find.bySemanticsLabel("Start recording"), findsNothing);
    expect(
      tester.widget<PromptInput>(find.byType(PromptInput)).surfaceStyleController.value,
      PregoComposerSurfaceStyle.emphasized,
    );

    await tester.tap(find.text("Ask anything..."));
    await tester.pump();
    expect(find.byType(EditableText), findsOneWidget);
  });
  for (final closeFromDetail in [false, true]) {
    testWidgets("desktop harness modal X preserves the live composer draft (detail: $closeFromDetail)", (tester) async {
      await getIt.reset();
      addTearDown(getIt.reset);
      registerFallbackValue(ComposerDraft.typed(text: ""));
      final newSessionCubit = _MockNewSessionCubit();
      final inputModeCubit = _MockChatInputModeCubit();
      whenListen(newSessionCubit, const Stream<NewSessionState>.empty(), initialState: _state);
      when(() => newSessionCubit.needsHarnessDiscovery).thenReturn(false);
      when(() => newSessionCubit.hasNoHarnesses).thenReturn(false);
      when(() => newSessionCubit.canCreateSession).thenReturn(true);
      var draft = ComposerDraft.typed(text: "");
      when(() => newSessionCubit.composerDraft).thenAnswer((_) => draft);
      when(() => newSessionCubit.saveComposerDraft(draft: any(named: "draft"))).thenAnswer((invocation) {
        draft = invocation.namedArguments[#draft]! as ComposerDraft;
      });
      whenListen(inputModeCubit, const Stream<ChatInputMode>.empty(), initialState: ChatInputMode.voiceFirst);
      final service = _MockPluginManagementService();
      final scans = _MockCatalogRescanService();
      final snapshots = BehaviorSubject<PluginManagementLoadResult>.seeded(
        const PluginManagementLoadResult.supported(
          response: PluginManagementResponse(
            snapshotToken: "navigation-test",
            bridgeId: "bridge",
            defaultPluginId: "test",
            defaultIdleTimeoutMins: 10,
            plugins: [],
          ),
          refreshError: null,
        ),
      );
      final installs = BehaviorSubject<Map<String, PluginInstallState>>.seeded(const {});
      addTearDown(snapshots.close);
      addTearDown(installs.close);
      when(() => service.snapshots).thenAnswer((_) => snapshots.stream);
      when(() => service.installStates).thenAnswer((_) => installs.stream);
      when(() => service.authenticationTerminal)
          .thenAnswer((_) => const Stream<PluginAuthenticationTerminalUpdate>.empty());
      when(service.onDispose).thenAnswer((_) async {});
      final scanStates = BehaviorSubject<CatalogRescanState>.seeded(const CatalogRescanState.idle());
      addTearDown(scanStates.close);
      when(() => scans.state).thenAnswer((_) => scanStates.stream);
      when(scans.onDispose).thenAnswer((_) async {});
      getIt.registerSingleton<PluginManagementService>(service);
      getIt.registerSingleton<CatalogRescanService>(scans);
      getIt.registerSingleton<UrlLauncher>(_MockUrlLauncher());
      final router = GoRouter(
        initialLocation: "/projects/p/sessions/new",
        routes: [
          GoRoute(
            path: "/projects/p/sessions/new",
            builder: (context, _) => DesktopNewSessionView(
              projectId: "p",
              projectName: "Project",
              onBack: () {},
              onOpenHarnessSettings: () => context.push<void>(
                const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.modal).buildPath(),
              ),
              onSessionCreated: ({required session}) {},
            ),
          ),
          buildDesktopHarnessSettingsRoute(),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<NewSessionCubit>.value(value: newSessionCubit),
            BlocProvider<ChatInputModeCubit>.value(value: inputModeCubit),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: buildPregoThemeData(brightness: Brightness.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("Ask anything..."));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), "unfinished desktop idea");
      await tester.pump();
      final opener = tester.element(find.byType(DesktopNewSessionView));
      final composer = tester.element(find.byType(PromptInput));
      tester.widget<DesktopNewSessionView>(find.byType(DesktopNewSessionView)).onOpenHarnessSettings();
      await tester.pumpAndSettle();
      final overview = tester.element(find.byType(HarnessesSettingsView));
      final harnessCubit = overview.read<PluginManagementCubit>();
      if (closeFromDetail) {
        unawaited(
          GoRouter.of(overview).push<void>(
            const AppRoute.settingsHarnessDetail(
              pluginId: "removed",
              presentation: HarnessSettingsPresentation.modal,
            ).buildPath(),
          ),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.bySemanticsLabel("Close settings"));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(DesktopNewSessionView)), same(opener));
      expect(tester.element(find.byType(PromptInput)), same(composer));
      expect(composer.read<NewSessionCubit>(), same(newSessionCubit));
      expect(draft, ComposerDraft.typed(text: "unfinished desktop idea"));
      expect(find.text("unfinished desktop idea"), findsOneWidget);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(harnessCubit.isClosed, isTrue);
      expect(snapshots.hasListener, isFalse);
    });
  }
}
