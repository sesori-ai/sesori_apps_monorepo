import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/features/auth_gate/auth_gate.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockAuthGateCubit() extends MockCubit<AuthGateState> implements AuthGateCubit;

const AuthUser _user = AuthUser(
  id: "user-1",
  provider: AuthProvider.github,
  providerUserId: "gh-1",
  providerUsername: "alex",
);

void main() {
  late _MockAuthGateCubit cubit;

  setUp(() {
    cubit = _MockAuthGateCubit();
    when(() => cubit.onSignedInDestinationReady()).thenAnswer((_) async {});
  });

  Future<void> pumpGate({required WidgetTester tester}) => tester.pumpWidget(
    MaterialApp(
      theme: buildPregoThemeData(brightness: Brightness.light),
      home: BlocProvider<AuthGateCubit>.value(
        value: cubit,
        child: const AuthGateView(child: Text("cockpit")),
      ),
    ),
  );

  testWidgets("checking renders a progress indicator", (tester) async {
    whenListen(cubit, const Stream<AuthGateState>.empty(), initialState: const AuthGateState.checking());
    await pumpGate(tester: tester);
    expect(find.byType(PregoActivityIndicator), findsOneWidget);
  });

  testWidgets("signedIn renders the supplied cockpit", (tester) async {
    whenListen(cubit, const Stream<AuthGateState>.empty(), initialState: const AuthGateState.signedIn(user: _user));
    await pumpGate(tester: tester);
    expect(find.text("cockpit"), findsOneWidget);
  });

  testWidgets("signed-in destination starts relay for a token-only restore", (tester) async {
    whenListen(
      cubit,
      Stream<AuthGateState>.value(const AuthGateState.signedIn(user: null)),
      initialState: const AuthGateState.checking(),
    );
    await pumpGate(tester: tester);
    await tester.pump();
    verify(() => cubit.onSignedInDestinationReady()).called(1);
  });
}
