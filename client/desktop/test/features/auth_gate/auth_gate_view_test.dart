import "package:bloc_test/bloc_test.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/features/auth_gate/auth_gate.dart";
import "package:sesori_desktop/features/home/home_placeholder.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";

class _MockAuthGateCubit extends MockCubit<AuthGateState> implements AuthGateCubit {}

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
  });

  Future<void> pumpGate(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthGateCubit>.value(
          value: cubit,
          child: const AuthGateView(),
        ),
      ),
    );
  }

  testWidgets("checking renders a progress indicator", (WidgetTester tester) async {
    whenListen(cubit, const Stream<AuthGateState>.empty(), initialState: const AuthGateState.checking());

    await pumpGate(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets("signedIn renders the home placeholder with the account", (WidgetTester tester) async {
    whenListen(cubit, const Stream<AuthGateState>.empty(), initialState: const AuthGateState.signedIn(user: _user));

    await pumpGate(tester);

    expect(find.byType(HomePlaceholder), findsOneWidget);
    expect(find.textContaining("alex"), findsOneWidget);
  });

  testWidgets("sign out button delegates to the cubit", (WidgetTester tester) async {
    whenListen(cubit, const Stream<AuthGateState>.empty(), initialState: const AuthGateState.signedIn(user: _user));
    when(() => cubit.signOut()).thenAnswer((_) async {});

    await pumpGate(tester);
    await tester.tap(find.text("Sign out"));

    verify(() => cubit.signOut()).called(1);
  });
}
