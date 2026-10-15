import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _Inventory() extends Mock implements McpCubit;
class _Actions() extends Mock implements McpActionCubit;
class _Authentication() extends Mock implements McpAuthenticationCubit;

const _target = McpServerTarget(
  scope: McpSessionScope(sessionId: "fixture"),
  serverKey: "fixture-server",
);
const _request = McpInventoryRequest(
  pluginId: "fixture",
  scope: McpSessionScope(sessionId: "fixture"),
);
const _server = McpServerSnapshot(
  serverTarget: _target,
  name: "Fixture server",
  description: null,
  endpointOrigin: null,
  connection: McpConnectionStatus(phase: McpConnectionPhase.connected),
  authorization: McpAuthorizationState.unknown,
  authentication: McpAuthenticationCapabilityAvailable(effectScope: McpActionEffectScope.harness),
  credentialForgetting: McpAuthenticationCapabilityAvailable(effectScope: McpActionEffectScope.harness),
  configuration: null,
  tools: McpToolsAvailable(tools: []),
  actions: [
    McpServerActionCapability(action: McpServerAction.reconnect, effectScope: McpActionEffectScope.session),
    McpServerActionCapability(action: McpServerAction.enable, effectScope: McpActionEffectScope.session),
    McpServerActionCapability(action: McpServerAction.disable, effectScope: McpActionEffectScope.session),
  ],
);

McpAuthenticationClientState _auth({
  required McpAuthenticationState native,
  required McpAuthenticationBrowserState browser,
  required McpAuthenticationRequestState request,
}) => McpAuthenticationClientState(
  observation: McpAuthenticationObserved(state: native, refreshFailure: null),
  browser: browser,
  request: request,
);

void main() {
  late _Inventory inventory;
  late _Actions actions;
  late _Authentication authentication;
  late BehaviorSubject<McpActionClientState> actionStates;
  late BehaviorSubject<McpAuthenticationClientState> authStates;
  late GoRouter router;
  const start = McpAuthenticationStartRequest(pluginId: "fixture", target: _target);
  const forget = McpForgetAuthenticationEntryAction(target: _target);
  setUp(() {
    registerFallbackValue(start);
    inventory = _Inventory();
    actions = _Actions();
    authentication = _Authentication();
    when(() => inventory.request).thenReturn(_request);
    when(() => inventory.mutationsAllowed).thenReturn(true);
    const ready = McpInventoryReady(
      inventory: McpInventorySnapshot(
        scope: McpSessionScope(sessionId: "fixture"),
        entries: [_server],
        servers: McpCatalogAvailable(),
        connectors: McpCatalogNotSupported(),
      ),
      refresh: McpInventoryRefreshIdle(),
    );
    when(() => inventory.state).thenReturn(ready);
    when(() => inventory.stream).thenAnswer((_) => const Stream<McpInventoryState>.empty());
    actionStates = BehaviorSubject.seeded(const McpActionIdle());
    when(() => actions.isClosed).thenReturn(false);
    when(() => actions.state).thenAnswer((_) => actionStates.value);
    when(() => actions.stream).thenAnswer((_) => actionStates.stream);
    when(() => actions.execute(action: forget)).thenAnswer((_) async {});
    authStates = BehaviorSubject.seeded(
      _auth(
        native: const McpAuthenticationIdle(),
        browser: const McpAuthenticationBrowserIdle(),
        request: const McpAuthenticationRequestIdle(),
      ),
    );
    when(() => authentication.state).thenAnswer((_) => authStates.value);
    when(() => authentication.stream).thenAnswer((_) => authStates.stream);
    when(() => authentication.start(request: any(named: "request"))).thenAnswer((_) async {});
    when(() => authentication.openBrowser()).thenAnswer((_) async {});
    when(() => authentication.cancel()).thenAnswer((_) async {});
    when(() => authentication.refresh()).thenAnswer((_) async {});
  });
  tearDown(() async {
    router.dispose();
    await actionStates.close();
    await authStates.close();
  });

  Widget app({required bool controls, required double scale}) {
    router = GoRouter(
      routes: [
        GoRoute(
          path: "/",
          builder: (_, _) =>
              Scaffold(body: controls ? const McpServerControlsView(target: _target) : const McpInventoryView()),
        ),
      ],
    );
    return MultiBlocProvider(
      providers: [
        BlocProvider<McpCubit>.value(value: inventory),
        BlocProvider<McpActionCubit>.value(value: actions),
        BlocProvider<McpAuthenticationCubit>.value(value: authentication),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: buildPregoThemeData(brightness: Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }

  Finder button(String label) => find.byWidgetPredicate((w) => w is PregoButtonsSolid && w.label == label);

  testWidgets(
    "native sign-in needs explicit browser intent, retains busy challenge and never displays private destinations",
    (tester) async {
      await tester.pumpWidget(app(controls: true, scale: 1));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(button("Sign in"), 200);
      await tester.tap(button("Sign in"));
      await tester.pumpAndSettle();
      final started = verify(() => authentication.start(request: captureAny(named: "request"))).captured
          .whereType<McpAuthenticationStartRequest>()
          .single;
      expect(started.pluginId, start.pluginId);
      expect(started.target, start.target);
      verifyNever(() => authentication.openBrowser());
      const attempt = McpAuthenticationAttempt(
        attemptId: "private-id",
        pluginId: "fixture",
        target: _target,
        cancellation: McpAuthenticationCancellation.cancelable,
      );
      const native = McpAuthenticationCallbackChallenge(
        attempt: attempt,
        authorizationUrl: "https://fixture.example/authorize?state=private-value",
        expectedCallbackUrl: "http://localhost:12345/return?state=private-value",
      );
      authStates.add(
        _auth(
          native: native,
          browser: const McpAuthenticationBrowserBlocked(),
          request: const McpAuthenticationRequestIdle(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(button("Open browser"), -200);
      await tester.tap(button("Open browser"));
      await tester.pumpAndSettle();
      verify(() => authentication.openBrowser()).called(1);
      final text = tester.widgetList<Text>(find.byType(Text)).map((w) => w.data).join(" ");
      expect(text, contains("Your challenge is retained"));
      expect(text, isNot(contains("private-value")));
      expect(text, isNot(contains("private-id")));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("native completion remains primary after a lost request response without shifting controls", (
    tester,
  ) async {
    await tester.pumpWidget(app(controls: true, scale: 1));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text("Fixture server"));
    const attempt = McpAuthenticationAttempt(
      attemptId: "fixture-id",
      pluginId: "fixture",
      target: _target,
      cancellation: McpAuthenticationCancellation.cancelable,
    );
    authStates.add(
      _auth(
        native: const McpAuthenticationCompleted(attempt: attempt),
        browser: const McpAuthenticationBrowserIdle(),
        request: McpAuthenticationRequestUncertain(cause: ApiError.generic()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Native sign-in completed. Refresh or reconnect to inspect available tools."), findsOneWidget);
    expect(find.text("The request response was lost. Native state is reported above."), findsOneWidget);
    expect(tester.getTopLeft(find.text("Fixture server")), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets("native-settlement-only cancellation stays disabled but preparation cancellation is available", (
    tester,
  ) async {
    await tester.pumpWidget(app(controls: true, scale: 1));
    await tester.pumpAndSettle();
    for (final mode in [McpAuthenticationCancellation.nativeSettlement, McpAuthenticationCancellation.unknown]) {
      final attempt = McpAuthenticationAttempt(
        attemptId: "fixture-id",
        pluginId: "fixture",
        target: _target,
        cancellation: mode,
      );
      authStates.add(
        _auth(
          native: McpAuthenticationStarting(attempt: attempt),
          browser: const McpAuthenticationBrowserIdle(),
          request: const McpAuthenticationRequestIdle(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<PregoButtonsSolid>(button("Cancel sign-in")).onPressed == null,
        mode == McpAuthenticationCancellation.nativeSettlement,
      );
    }
    await tester.tap(button("Cancel sign-in"));
    await tester.pumpAndSettle();
    verify(() => authentication.cancel()).called(1);
  });

  testWidgets("credential forgetting confirms its native scope and cancellation does not dispatch", (tester) async {
    await tester.pumpWidget(app(controls: true, scale: 1));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(button("Forget credentials"), 200);
    await tester.tap(button("Forget credentials"));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Clear the native saved credentials. Server configuration stays in place; a current connection may remain active.",
      ),
      findsOneWidget,
    );
    await tester.tap(button("Cancel"));
    await tester.pumpAndSettle();
    verifyNever(() => actions.execute(action: forget));
    await tester.tap(button("Forget credentials"));
    await tester.pumpAndSettle();
    await tester.tap(button("Forget credentials").last);
    await tester.pumpAndSettle();
    verify(() => actions.execute(action: forget)).called(1);
    expect(tester.takeException(), isNull);
  });

  testWidgets("read-only inventory hides management", (
    tester,
  ) async {
    when(() => inventory.mutationsAllowed).thenReturn(false);
    await tester.pumpWidget(app(controls: false, scale: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Fixture server"));
    await tester.pumpAndSettle();
    expect(button("Manage connection"), findsNothing);
    verifyNever(() => authentication.cancel());
  });

  testWidgets("an observed native operation blocks sign-in and forgetting until refreshed", (tester) async {
    authStates.add(
      const McpAuthenticationClientState(
        observation: McpAuthenticationObserved(
          state: McpAuthenticationIdle(),
          refreshFailure: McpAuthenticationReceived(result: McpAuthenticationBusy()),
        ),
        request: McpAuthenticationRequestIdle(),
        browser: McpAuthenticationBrowserIdle(),
      ),
    );
    await tester.pumpWidget(app(controls: true, scale: 1));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(button("Sign in"), 200);
    expect(tester.widget<PregoButtonsSolid>(button("Sign in")).onPressed, isNull);
    await tester.scrollUntilVisible(button("Forget credentials"), 200);
    expect(tester.widget<PregoButtonsSolid>(button("Forget credentials")).onPressed, isNull);
    authStates.add(
      _auth(
        native: const McpAuthenticationIdle(),
        browser: const McpAuthenticationBrowserIdle(),
        request: const McpAuthenticationRequestIdle(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<PregoButtonsSolid>(button("Forget credentials")).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets("an action outcome on another server is not presented as this server's result", (tester) async {
    actionStates.add(
      const McpActionReceivedState(
        request: McpEntryActionRequest(
          pluginId: "fixture",
          action: McpServerEntryAction(
            target: McpServerTarget(
              scope: McpSessionScope(sessionId: "fixture"),
              serverKey: "other-server",
            ),
            action: McpServerAction.reconnect,
          ),
        ),
        result: McpActionFailed(),
      ),
    );
    await tester.pumpWidget(app(controls: true, scale: 1));
    await tester.pumpAndSettle();
    expect(find.text("The native action failed. Refresh the inventory before trying again."), findsNothing);
    expect(find.text("Choose a supported action."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("pending connector setup blocks controls without claiming a native server action", (tester) async {
    actionStates.add(
      const McpActionPending(
        request: McpEntryActionRequest(
          pluginId: "fixture",
          action: McpConnectorSetupEntryAction(
            offerTarget: McpConnectorOfferTarget(
              scope: McpSessionScope(sessionId: "fixture"),
              offerKey: "connector",
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(controls: true, scale: 1));
    await tester.pumpAndSettle();
    expect(find.text("Applying native action…"), findsNothing);
    expect(find.text("Choose a supported action."), findsOneWidget);
    expect(tester.widget<PregoButtonsSolid>(button("Reconnect")).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets("phone-sized large text keeps controls scrollable without overflow", (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(controls: true, scale: 2));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(button("Forget credentials"), 250);
    expect(button("Forget credentials"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
