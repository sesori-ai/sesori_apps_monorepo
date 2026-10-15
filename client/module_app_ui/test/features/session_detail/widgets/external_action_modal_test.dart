import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

const _action = PendingExternalAction(
  id: "request",
  sessionID: "owner",
  displaySessionId: "display",
  title: "Fixture MCP",
  message: "Authorize the fixture in your browser.",
  authorizationUrl: "https://fixture.example/authorize?private=fixture-only",
  purpose: ExternalActionPurpose.authorization,
  choices: [ExternalActionChoice.accept, ExternalActionChoice.decline, ExternalActionChoice.cancel],
);

class _Harness() {
  final repository = MockSessionRepository();
  final connection = MockConnectionService();
  final launcher = MockUrlLauncher();
  final pendingChanges = StreamController<bool>.broadcast();
  final statuses = BehaviorSubject<ConnectionStatus>.seeded(
    const ConnectionStatus.connected(
      config: ServerConnectionConfig(relayHost: "fixture", authToken: "fixture", bridgeId: "fixture"),
      health: HealthResponse(healthy: true, version: "1.9.2", filesystemAccessDegraded: false),
    ),
  );
  bool pending = true;
  int settled = 0;
  int fallbackCancels = 0;
  this {
    when(() => connection.currentStatus).thenAnswer((_) => statuses.value);
    when(() => connection.status).thenAnswer((_) => statuses);
    when(() => repository.getPendingExternalActions(sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.success(const PendingExternalActionsResponse(data: [_action])));
    when(() => repository.replyToExternalAction(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const ExternalActionReplyAccepted()));
    when(() => launcher.launch(any(), mode: UrlLaunchMode.externalApp)).thenAnswer((_) async => true);
  }
  late final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, _) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showExternalActionModal(
                context: context,
                requestId: "request",
                sessionId: "owner",
                createCubit: ({required requestId, required sessionId}) => SessionExternalActionCubit(
                  service: SessionExternalActionService(repository: repository),
                  connectionService: connection,
                  urlLauncher: launcher,
                  requestId: requestId,
                  sessionId: sessionId,
                ),
                isPendingStream: pendingChanges.stream,
                isPending: () => pending,
                onPendingDismissed: () {},
                onSettled: () {
                  settled++;
                  pending = false;
                  pendingChanges.add(false);
                },
                onCancelUnavailable: () {
                  fallbackCancels++;
                },
              ),
              child: const Text("Open request"),
            ),
          ),
        ),
      ),
    ],
  );
  Widget app({required double scale}) => MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
  );
  Future<void> close() async {
    router.dispose();
    await pendingChanges.close();
    await statuses.close();
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse("https://fixture.example"));
    registerFallbackValue(
      const ReplyToExternalActionRequest(requestId: "request", sessionId: "owner", choice: ExternalActionChoice.cancel),
    );
  });
  late _Harness harness;
  setUp(() {
    harness = _Harness();
  });
  tearDown(() async {
    await harness.close();
  });
  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness.app(scale: scale));
    await tester.tap(find.text("Open request"));
    await tester.pumpAndSettle();
  }

  testWidgets("browser intent is explicit and leaves native consent separate with stable controls", (tester) async {
    await open(tester);
    expect(find.text("https://fixture.example"), findsOneWidget);
    expect(find.textContaining("private=fixture-only"), findsNothing);
    verifyNever(() => harness.launcher.launch(any(), mode: UrlLaunchMode.externalApp));
    final before = tester.getTopLeft(find.text("Open browser"));
    await tester.tap(find.widgetWithText(PregoButtonsSolid, "Open browser"));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text("Open browser")), before);
    expect(find.textContaining("does not confirm authorization"), findsOneWidget);
    verifyNever(() => harness.repository.replyToExternalAction(request: any(named: "request")));
    await tester.tap(find.widgetWithText(PregoButtonsSolid, "Decline request"));
    await tester.pumpAndSettle();
    final request =
        verify(() => harness.repository.replyToExternalAction(request: captureAny(named: "request"))).captured.single
            as ReplyToExternalActionRequest;
    expect(request.sessionId, "owner");
    expect(request.choice, ExternalActionChoice.decline);
    expect(harness.settled, 1);
    expect(find.text("Fixture MCP"), findsNothing);
  });
  testWidgets("dismissal leaves the native request pending and reopening reads it again", (tester) async {
    await open(tester);
    harness.router.pop();
    await tester.pumpAndSettle();
    expect(harness.pending, isTrue);
    expect(harness.settled, 0);
    expect(harness.fallbackCancels, 0);
    verifyNever(() => harness.repository.replyToExternalAction(request: any(named: "request")));
    await tester.tap(find.text("Open request"));
    await tester.pumpAndSettle();
    expect(find.text("Fixture MCP"), findsOneWidget);
    verify(() => harness.repository.getPendingExternalActions(sessionId: "owner")).called(2);
  });
  testWidgets("a request settled while closed is acknowledged and dismissed on read", (tester) async {
    when(() => harness.repository.getPendingExternalActions(sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.success(const PendingExternalActionsResponse(data: [])));
    await open(tester);
    expect(harness.settled, 1);
    expect(find.byType(ExternalActionModal), findsNothing);
    verifyNever(() => harness.repository.replyToExternalAction(request: any(named: "request")));
  });

  testWidgets("unreadable snapshot keeps an explicit legacy cancel path", (tester) async {
    when(() => harness.repository.getPendingExternalActions(sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.error(NonSuccessCodeError(errorCode: 422, rawErrorString: null)));
    await open(tester);
    expect(find.text("Open browser"), findsNothing);
    await tester.tap(find.widgetWithText(PregoButtonsSolid, "Cancel request"));
    await tester.pumpAndSettle();
    expect(harness.fallbackCancels, 1);
    expect(harness.settled, 0);
  });
  for (final purpose in [ExternalActionPurpose.authorization, ExternalActionPurpose.unknown]) {
    testWidgets("only declared known choices are offered for ${purpose.name}", (tester) async {
      final action = PendingExternalAction(
        id: _action.id,
        sessionID: _action.sessionID,
        displaySessionId: _action.displaySessionId,
        title: _action.title,
        message: _action.message,
        authorizationUrl: _action.authorizationUrl,
        purpose: purpose,
        choices: const [ExternalActionChoice.unknown, ExternalActionChoice.cancel],
      );
      when(() => harness.repository.getPendingExternalActions(sessionId: "owner"))
          .thenAnswer((_) async => ApiResponse.success(PendingExternalActionsResponse(data: [action])));
      await open(tester);
      expect(find.text("Continue in coding agent"), findsNothing);
      expect(find.text("Decline request"), findsNothing);
      if (purpose == ExternalActionPurpose.unknown) expect(find.text("Open browser"), findsNothing);
      await tester.tap(find.widgetWithText(PregoButtonsSolid, "Cancel request"));
      await tester.pumpAndSettle();
      final request =
          verify(() => harness.repository.replyToExternalAction(request: captureAny(named: "request"))).captured.single
              as ReplyToExternalActionRequest;
      expect(request.choice, ExternalActionChoice.cancel);
    });
  }
  testWidgets("large text remains scrollable and disconnect removes consent controls", (tester) async {
    await open(tester, scale: 2);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text("Cancel request"));
    await tester.pumpAndSettle();
    harness.statuses.add(const ConnectionStatus.disconnected());
    await tester.pumpAndSettle();
    expect(find.text("Open browser"), findsNothing);
    expect(find.text("Continue in coding agent"), findsNothing);
    expect(find.textContaining("connection changed"), findsOneWidget);
    verifyNever(() => harness.repository.replyToExternalAction(request: any(named: "request")));
  });
}
