import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
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

Widget _buildApp({required MockLoginCubit cubit, required VoidCallback onSignedIn}) => MaterialApp(
  theme: ThemeData(extensions: [PregoDesignSystem.light]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: BlocProvider<LoginCubit>.value(
      value: cubit,
      child: SingleChildScrollView(child: EmailLoginForm(onSignedIn: onSignedIn)),
    ),
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
  late int signedInCalls;

  Future<void> pumpForm(WidgetTester tester) =>
      tester.pumpWidget(_buildApp(cubit: cubit, onSignedIn: () => signedInCalls++));

  setUp(() {
    cubit = MockLoginCubit();
    signedInCalls = 0;
    _stubState(cubit, const LoginState.idle());
  });

  testWidgets("renders labelled email and password fields and a submit button", (tester) async {
    await pumpForm(tester);

    expect(find.byType(PregoInputField), findsNWidgets(2));
    // Every field is required, so none carries a marker.
    expect(find.text("Email"), findsOneWidget);
    expect(find.text("Password"), findsOneWidget);
    expect(find.textContaining("*"), findsNothing);
    expect(find.text("Sign in"), findsOneWidget);
  });

  testWidgets("does not submit while the email is invalid", (tester) async {
    await pumpForm(tester);

    await _fillCredentials(tester, email: "not-an-email");
    await tester.tap(find.text("Sign in"));
    await tester.pump();

    expect(find.text("Please enter a valid email"), findsOneWidget);
    verifyNever(
      () => cubit.loginWithEmail(
        email: any(named: "email"),
        password: any(named: "password"),
      ),
    );
  });

  testWidgets("does not submit while the password is empty", (tester) async {
    await pumpForm(tester);

    await _fillCredentials(tester, password: "");
    await tester.tap(find.text("Sign in"));
    await tester.pump();

    expect(find.text("Password is required"), findsOneWidget);
    verifyNever(
      () => cubit.loginWithEmail(
        email: any(named: "email"),
        password: any(named: "password"),
      ),
    );
  });

  testWidgets("submits trimmed credentials and hands a success to the host", (tester) async {
    when(
      () => cubit.loginWithEmail(
        email: any(named: "email"),
        password: any(named: "password"),
      ),
    ).thenAnswer((_) async => true);
    await pumpForm(tester);

    await _fillCredentials(tester, email: "  alex@example.com  ");
    await tester.tap(find.text("Sign in"));
    await tester.pump();

    verify(() => cubit.loginWithEmail(email: "alex@example.com", password: "hunter2")).called(1);
    expect(signedInCalls, 1);
  });

  testWidgets("a rejected sign-in stays in the form", (tester) async {
    when(
      () => cubit.loginWithEmail(
        email: any(named: "email"),
        password: any(named: "password"),
      ),
    ).thenAnswer((_) async => false);
    await pumpForm(tester);

    await _fillCredentials(tester);
    await tester.tap(find.text("Sign in"));
    await tester.pump();

    expect(signedInCalls, 0);
  });

  testWidgets("password is obscured until the visibility toggle is tapped", (tester) async {
    await pumpForm(tester);

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
    await pumpForm(tester);

    expect(find.byType(PregoInlineAlertsNotifications), findsOneWidget);
    expect(find.text("Authentication failed"), findsOneWidget);
    expect(find.text("Sign in failed. Please try again."), findsOneWidget);
  });

  testWidgets("disables the fields while authenticating", (tester) async {
    _stubState(cubit, const LoginState.authenticating());
    await pumpForm(tester);

    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isFalse);
    expect(tester.widget<TextField>(find.byType(TextField).last).enabled, isFalse);
  });
}
