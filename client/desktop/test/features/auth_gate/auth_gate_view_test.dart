import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/features/auth_gate/auth_gate.dart";
import "package:sesori_desktop/features/home/desktop_home.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockAuthGateCubit() extends MockCubit<AuthGateState> implements AuthGateCubit;

class _MockBridgeControlCubit() extends MockCubit<BridgeControlState> implements BridgeControlCubit;

class _MockConnectionOverlayCubit() extends MockCubit<ConnectionOverlayState> implements ConnectionOverlayCubit;

const AuthUser _user = AuthUser(
  id: "user-1",
  provider: AuthProvider.github,
  providerUserId: "gh-1",
  providerUsername: "alex",
);

void main() {
  late _MockAuthGateCubit cubit;
  late _MockBridgeControlCubit bridgeControlCubit;
  late _MockConnectionOverlayCubit connectionOverlayCubit;

  setUp(() {
    cubit = _MockAuthGateCubit();
    bridgeControlCubit = _MockBridgeControlCubit();
    connectionOverlayCubit = _MockConnectionOverlayCubit();
    whenListen(
      bridgeControlCubit,
      const Stream<BridgeControlState>.empty(),
      initialState: BridgeControlState(
        trayAvailability: SystemTrayAvailability.available,
        menu: SystemTrayMenu(entries: const <SystemTrayMenuEntry>[]),
        activity: BridgeControlActivity.idle,
        statusLabel: "Bridge: Off",
        processState: const BridgeProcessStopped(),
        desiredState: BridgeProcessDesiredState.off,
        toggleTarget: BridgeProcessDesiredState.on,
        launchAtLoginEnabled: false,
        controlStatus: BridgeControlStatus.offline,
      ),
    );
    whenListen(
      connectionOverlayCubit,
      const Stream<ConnectionOverlayState>.empty(),
      initialState: const ConnectionOverlayState.hidden(connected: false),
    );
    when(() => cubit.onSignedInDestinationReady()).thenAnswer((_) async {});
  });

  Future<void> pumpGate(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthGateCubit>.value(value: cubit),
            BlocProvider<BridgeControlCubit>.value(value: bridgeControlCubit),
            BlocProvider<ConnectionOverlayCubit>.value(value: connectionOverlayCubit),
          ],
          child: const AuthGateView(),
        ),
      ),
    );
  }

  testWidgets("checking renders a progress indicator", (WidgetTester tester) async {
    whenListen(cubit, const Stream<AuthGateState>.empty(), initialState: const AuthGateState.checking());

    await pumpGate(tester);

    expect(find.byType(PregoActivityIndicator), findsOneWidget);
  });

  testWidgets("signedIn renders the desktop supervision home with the account", (WidgetTester tester) async {
    whenListen(cubit, const Stream<AuthGateState>.empty(), initialState: const AuthGateState.signedIn(user: _user));

    await pumpGate(tester);

    expect(find.byType(DesktopHome), findsOneWidget);
    expect(find.textContaining("alex"), findsOneWidget);
  });

  testWidgets("signed-in destination starts relay for a token-only restore", (WidgetTester tester) async {
    whenListen(
      cubit,
      Stream<AuthGateState>.value(const AuthGateState.signedIn(user: null)),
      initialState: const AuthGateState.checking(),
    );

    await pumpGate(tester);
    await tester.pump();

    verify(() => cubit.onSignedInDestinationReady()).called(1);
  });

  testWidgets("sign out button delegates to the cubit", (WidgetTester tester) async {
    whenListen(cubit, const Stream<AuthGateState>.empty(), initialState: const AuthGateState.signedIn(user: _user));
    when(() => cubit.signOut()).thenAnswer((_) async {});

    await pumpGate(tester);
    await tester.tap(find.text("Sign out"));

    verify(() => cubit.signOut()).called(1);
  });
}
