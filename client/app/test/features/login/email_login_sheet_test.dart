import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/login/email_login_sheet.dart";
import "package:theme_prego/module_prego.dart";

class MockLoginCubit() extends Mock implements LoginCubit;

/// Drives [LoginCubit.state]/[LoginCubit.stream] from a plain seed so tests can
/// stage a state without standing up the real cubit's auth dependencies.
void _stubState(MockLoginCubit cubit, LoginState state) {
  when(() => cubit.state).thenReturn(state);
  when(() => cubit.stream).thenAnswer((_) => Stream<LoginState>.value(state));
  when(() => cubit.isClosed).thenReturn(false);
  when(cubit.close).thenAnswer((_) async {});
}

/// Hosts a button that presents the sheet via [showEmailLoginSheet], so tests
/// can exercise the presenter rather than the sheet widget in isolation. Uses a
/// real [GoRouter] so the sheet's `context.pop()` on success resolves, as it
/// does in the app.
Widget _buildPresenter(MockLoginCubit cubit) => MaterialApp.router(
  theme: ThemeData(extensions: [PregoDesignSystem.light]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEmailLoginSheet(context: context, cubit: cubit),
              child: const Text("Open"),
            ),
          ),
        ),
      ),
    ],
  ),
);

Future<void> _fillCredentials(
  WidgetTester tester, {
  String email = "alex@example.com",
  String password = "hunter2",
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.pump();
}

void main() {
  late MockLoginCubit cubit;

  setUp(() {
    cubit = MockLoginCubit();
    _stubState(cubit, const LoginState.idle());
  });

  testWidgets("submits trimmed credentials to the cubit and closes on success", (tester) async {
    when(
      () => cubit.loginWithEmail(
        email: any(named: "email"),
        password: any(named: "password"),
      ),
    ).thenAnswer((_) async => true);

    await tester.pumpWidget(_buildPresenter(cubit));
    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();

    await _fillCredentials(tester, email: "  alex@example.com  ");
    await tester.tap(find.text("Sign in"));
    await tester.pumpAndSettle();

    verify(() => cubit.loginWithEmail(email: "alex@example.com", password: "hunter2")).called(1);
    // A successful sign-in pops the sheet.
    expect(find.byType(EmailLoginForm), findsNothing);
  });

  testWidgets("clears a stale provider failure when the sheet opens", (tester) async {
    // A provider sign-in failed and the user opened the email sheet without
    // dismissing the banner, so the shared cubit is still in LoginFailed.
    _stubState(cubit, const LoginState.failed(reason: LoginFailedReason.declined));

    await tester.pumpWidget(_buildPresenter(cubit));
    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();

    // Opening the sheet stands the shared failure down so the stale provider
    // error isn't rendered inline above the email fields before any submission.
    verify(() => cubit.onDismissedLoginFailureError()).called(1);
  });
}
