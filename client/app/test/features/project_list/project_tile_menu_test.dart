import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/features/project_list/project_list_screen.dart";
import "package:sesori_mobile/features/project_list/rename_project_dialog.dart";
import "package:sesori_mobile/features/project_list/widgets/project_tile.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// Long-pressing a project row opens its actions in an anchored popover
/// ([PregoAnchorMenu]) rather than a bottom sheet, so the row stays visible
/// beside the menu. The menu is forced flat, so both platforms take the same
/// path — the `InkWell` rows of [PregoAnchorMenu]'s flat panel — and neither
/// raises a [PregoBottomSheet].
void main() {
  const config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "test-token");
  const health = HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: null);
  const connected = ConnectionStatus.connected(config: config, health: health);

  late BehaviorSubject<ConnectionStatus> statusController;
  late MockConnectionService mockConnectionService;
  late MockProjectService mockProjectService;
  late MockRegisteredBridgesService mockRegisteredBridgesService;
  late StubConnectionOverlayCubit overlayCubit;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    statusController = BehaviorSubject<ConnectionStatus>.seeded(connected);
    mockConnectionService = MockConnectionService();
    mockProjectService = MockProjectService();
    mockRegisteredBridgesService = MockRegisteredBridgesService();
    overlayCubit = StubConnectionOverlayCubit();

    when(() => mockConnectionService.status).thenAnswer((_) => statusController.stream);
    when(() => mockConnectionService.currentStatus).thenAnswer((_) => statusController.value);
    when(() => mockConnectionService.connectWithFreshAuthToken()).thenAnswer((_) async => true);
    when(() => mockRegisteredBridgesService.hasRegisteredBridges()).thenAnswer((_) async => true);
    // Hiding the only project empties the list, and the cubit enriches the
    // empty state with the bridges it would offer to add a project on.
    when(() => mockRegisteredBridgesService.getRegisteredBridges()).thenAnswer((_) async => const []);

    getIt.registerLazySingleton<ProjectService>(() => mockProjectService);
    registerListServices(projectService: mockProjectService);
    getIt.registerLazySingleton<ConnectionService>(() => mockConnectionService);
    getIt.registerLazySingleton<SseEventTracker>(MockSseEventTracker.new);
    getIt.registerLazySingleton<RouteSource>(MockRouteSource.new);
    getIt.registerLazySingleton<SessionUnseenTracker>(FakeSessionUnseenTracker.new);
    getIt.registerLazySingleton<RegisteredBridgesService>(() => mockRegisteredBridgesService);
    getIt.registerLazySingleton<FailureReporter>(MockFailureReporter.new);
  });

  tearDown(() async {
    await overlayCubit.close();
    await statusController.close();
    await getIt.reset();
  });

  final project = testProject(id: "/home/user/my-app", path: "/home/user/my-app");

  /// Pumps the real screen with a single project loaded. A router hosts it
  /// because the rename sheet pops itself with go_router's `context.pop()`.
  Future<void> pumpScreen(WidgetTester tester) async {
    when(() => mockProjectService.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(Projects(data: [project])),
    );

    final router = GoRouter(
      routes: [
        GoRoute(path: "/", builder: (_, _) => const ProjectListScreen()),
        GoRoute(path: "/projects/:projectId/sessions", builder: (_, _) => const SizedBox.shrink()),
      ],
    );

    await tester.pumpWidget(
      BlocProvider<ConnectionOverlayCubit>.value(
        value: overlayCubit,
        child: MaterialApp.router(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Long-presses the project's row. The finder targets the row's title so the
  /// press lands on the tile, not on the popover the press opens.
  Future<void> longPressTile(WidgetTester tester) async {
    await tester.longPress(find.widgetWithText(ProjectTile, "my-app"));
    await tester.pumpAndSettle();
  }

  testWidgets("long-pressing a project opens its actions in an anchored menu, not a bottom sheet", (tester) async {
    await pumpScreen(tester);

    // The actions are absent until the row is long-pressed…
    expect(find.text("Rename"), findsNothing);
    expect(find.text("Hide Project"), findsNothing);

    await longPressTile(tester);

    // …and land in the flat anchored panel's InkWell rows. A tap-and-release
    // long press must leave the menu up: the popover's barrier is pushed while
    // the finger is still down, so a barrier that swallowed the lift would
    // dismiss the menu the instant it opened.
    expect(find.widgetWithText(InkWell, "Rename"), findsOneWidget);
    expect(find.widgetWithText(InkWell, "Hide Project"), findsOneWidget);
    expect(find.byType(PregoBottomSheet), findsNothing);

    // The row it is anchored to stays on screen behind the menu — the whole
    // point of a popover over a sheet.
    expect(find.widgetWithText(ProjectTile, "my-app"), findsOneWidget);
  });

  testWidgets("right-clicking a project opens the same anchored menu without navigating", (tester) async {
    await pumpScreen(tester);

    // The mouse counterpart of the long-press, for the desktop app.
    await tester.tap(find.widgetWithText(ProjectTile, "my-app"), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InkWell, "Rename"), findsOneWidget);
    expect(find.widgetWithText(InkWell, "Hide Project"), findsOneWidget);
    // A secondary click must not double as the row's tap — the list is still
    // here, not the sessions route.
    expect(find.widgetWithText(ProjectTile, "my-app"), findsOneWidget);
  });

  // Pinned to iOS because the blur is Apple-only: a full-screen BackdropFilter is
  // the cost PregoAnchorMenu's flat path exists to keep off Android, so there the
  // spotlight runs as scrim + cut-out alone. That degrade is PregoAnchorMenu's
  // contract and is covered in module_prego; what matters here is only that the
  // project row opts into the spotlight at all.
  testWidgets("the open menu blurs the page behind it and releases the blur on dismiss", (tester) async {
    await pumpScreen(tester);

    expect(find.byType(BackdropFilter), findsNothing);

    await longPressTile(tester);

    expect(find.byType(BackdropFilter), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.byType(BackdropFilter), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets("Hide Project dismisses the menu, hides the project, and confirms with a snackbar", (tester) async {
    when(() => mockProjectService.hideProject(projectId: any(named: "projectId"))).thenAnswer(
      (_) async => ApiResponse.success(null),
    );

    await pumpScreen(tester);
    await longPressTile(tester);

    await tester.tap(find.widgetWithText(InkWell, "Hide Project"));
    await tester.pumpAndSettle();

    verify(() => mockProjectService.hideProject(projectId: project.id)).called(1);
    expect(find.text("Hide Project"), findsNothing);
    expect(find.text("Project hidden"), findsOneWidget);
    // The bridge confirmed, so the row is gone.
    expect(find.widgetWithText(ProjectTile, "my-app"), findsNothing);
  });

  testWidgets("Hide Project reports the failure when the bridge rejects the hide", (tester) async {
    // The cubit only drops the project once the bridge confirms; a rejected
    // hide must not claim success while the row stays in the list.
    when(() => mockProjectService.hideProject(projectId: any(named: "projectId"))).thenAnswer(
      (_) async => ApiResponse.error(ApiError.generic()),
    );

    await pumpScreen(tester);
    await longPressTile(tester);

    await tester.tap(find.widgetWithText(InkWell, "Hide Project"));
    await tester.pumpAndSettle();

    expect(find.text("Project hidden"), findsNothing);
    expect(find.text("Failed to hide project"), findsOneWidget);
    expect(find.widgetWithText(ProjectTile, "my-app"), findsOneWidget);
  });

  testWidgets("Rename dismisses the menu and opens the rename sheet", (tester) async {
    await pumpScreen(tester);
    await longPressTile(tester);

    await tester.tap(find.widgetWithText(InkWell, "Rename"));
    await tester.pumpAndSettle();

    expect(find.byType(RenameProjectDialog), findsOneWidget);
    expect(find.widgetWithText(InkWell, "Rename"), findsNothing);
  });

  testWidgets("tapping outside the menu dismisses it without acting on the project", (tester) async {
    await pumpScreen(tester);
    await longPressTile(tester);

    // The transparent barrier fills the screen; the top-left corner is clear of
    // the panel, which anchors to the row.
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text("Rename"), findsNothing);
    expect(find.text("Hide Project"), findsNothing);
    verifyNever(() => mockProjectService.hideProject(projectId: any(named: "projectId")));
  });
}
