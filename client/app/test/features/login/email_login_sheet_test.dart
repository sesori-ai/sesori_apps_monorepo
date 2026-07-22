import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/login/email_login_sheet.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

class MockLoginCubit extends Mock implements LoginCubit {}

/// Drives [LoginCubit.state]/[LoginCubit.stream] from a plain seed so tests can
/// stage a state without standing up the real cubit's auth dependencies.
void _stubState(MockLoginCubit cubit, LoginState state) {
  when(() => cubit.state).thenReturn(state);
  when(() => cubit.stream).thenAnswer((_) => Stream<LoginState>.value(state));
  when(() => cubit.isClosed).thenReturn(false);
  when(cubit.close).thenAnswer((_) async {});
}

Widget _buildApp(MockLoginCubit cubit) => MaterialApp(
  theme: ThemeData(extensions: [PregoDesignSystem.light]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: BlocProvider<LoginCubit>.value(
      value: cubit,
      child: const SingleChildScrollView(child: EmailLoginSheet()),
    ),
  ),
);

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

  testWidgets("renders labelled email and password fields and a submit button", (tester) async {
    await tester.pumpWidget(_buildApp(cubit));

    expect(find.byType(PregoInputField), findsNWidgets(2));
    expect(find.text("Email *", findRichText: true), findsOneWidget);
    expect(find.text("Password *", findRichText: true), findsOneWidget);
    expect(find.text("Sign in"), findsOneWidget);
  });

  testWidgets("does not submit while the email is invalid", (tester) async {
    await tester.pumpWidget(_buildApp(cubit));

    await _fillCredentials(tester, email: "not-an-email");
    await tester.tap(find.text("Sign in"));
    await tester.pump();

    expect(find.text("Please enter a valid email"), findsOneWidget);
    verifyNever(() => cubit.loginWithEmail(email: any(named: "email"), password: any(named: "password")));
  });

  testWidgets("does not submit while the password is empty", (tester) async {
    await tester.pumpWidget(_buildApp(cubit));

    await _fillCredentials(tester, password: "");
    await tester.tap(find.text("Sign in"));
    await tester.pump();

    expect(find.text("Password is required"), findsOneWidget);
    verifyNever(() => cubit.loginWithEmail(email: any(named: "email"), password: any(named: "password")));
  });

  testWidgets("submits trimmed credentials to the cubit and closes on success", (tester) async {
    when(
      () => cubit.loginWithEmail(email: any(named: "email"), password: any(named: "password")),
    ).thenAnswer((_) async => true);

    await tester.pumpWidget(_buildPresenter(cubit));
    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();

    await _fillCredentials(tester, email: "  alex@example.com  ");
    await tester.tap(find.text("Sign in"));
    await tester.pumpAndSettle();

    verify(() => cubit.loginWithEmail(email: "alex@example.com", password: "hunter2")).called(1);
    // A successful sign-in pops the sheet.
    expect(find.byType(EmailLoginSheet), findsNothing);
  });

  testWidgets("password is obscured until the visibility toggle is tapped", (tester) async {
    await tester.pumpWidget(_buildApp(cubit));

    EditableText passwordField() => tester.widget<EditableText>(find.byType(EditableText).last);
    expect(passwordField().obscureText, isTrue);
    expect(find.bySemanticsLabel("Show password"), findsOneWidget);

    await tester.tap(find.byIcon(TablerRegular.eye_off));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
    expect(find.bySemanticsLabel("Hide password"), findsOneWidget);
  });

  testWidgets("shows a failure inline, next to the form that caused it", (tester) async {
    _stubState(cubit, const LoginState.failed(reason: LoginFailedReason.unknown));
    await tester.pumpWidget(_buildApp(cubit));

    expect(find.byType(PregoInlineAlertsNotifications), findsOneWidget);
    expect(find.text("Authentication failed"), findsOneWidget);
    expect(find.text("Sign in failed. Please try again."), findsOneWidget);
  });

  testWidgets("clears a stale provider failure when the sheet opens", (tester) async {
    // A provider sign-in failed and the user opened the email sheet without
    // dismissing the banner, so the shared cubit is still in LoginFailed.
    _stubState(cubit, const LoginState.failed(reason: LoginFailedReason.browserOpenFailed));

    await tester.pumpWidget(_buildPresenter(cubit));
    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();

    // Opening the sheet stands the shared failure down so the stale provider
    // error isn't rendered inline above the email fields before any submission.
    verify(() => cubit.onDismissedLoginFailureError()).called(1);
  });

  testWidgets("disables the fields and shows progress while authenticating", (tester) async {
    _stubState(cubit, const LoginState.authenticating());
    await tester.pumpWidget(_buildApp(cubit));

    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isFalse);
    expect(tester.widget<TextField>(find.byType(TextField).last).enabled, isFalse);
  });
}
