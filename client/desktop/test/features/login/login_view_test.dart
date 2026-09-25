import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/features/login/login_screen.dart";

class _MockLoginCubit() extends MockCubit<LoginState> implements LoginCubit;

LoginState _polling({required LoginBrowserLaunch browser}) => LoginState.polling(
  handoff: LoginHandoff(
    provider: AuthProvider.github,
    oauth: OAuthHandoff(
      authUrl: Uri.parse("https://auth.example.com/github"),
      expiresAt: DateTime(2026, 9, 25, 12, 5),
      deviceName: "Test Mac",
    ),
    browser: browser,
  ),
);

void main() {
  late _MockLoginCubit cubit;

  setUp(() {
    cubit = _MockLoginCubit();
  });

  Future<void> pumpLogin(WidgetTester tester, {required LoginState state}) {
    whenListen(cubit, const Stream<LoginState>.empty(), initialState: state);
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<LoginCubit>.value(
          value: cubit,
          child: const LoginView(),
        ),
      ),
    );
  }

  testWidgets("idle renders enabled provider buttons", (WidgetTester tester) async {
    await pumpLogin(tester, state: const LoginState.idle());

    final FilledButton github = tester.widget(find.widgetWithText(FilledButton, "Continue with GitHub"));
    final OutlinedButton google = tester.widget(find.widgetWithText(OutlinedButton, "Continue with Google"));
    expect(github.onPressed, isNotNull);
    expect(google.onPressed, isNotNull);
  });

  testWidgets("tapping GitHub starts the browser-poll flow", (WidgetTester tester) async {
    when(() => cubit.loginWithProvider(AuthProvider.github)).thenAnswer((_) async => true);
    await pumpLogin(tester, state: const LoginState.idle());

    await tester.tap(find.text("Continue with GitHub"));

    verify(() => cubit.loginWithProvider(AuthProvider.github)).called(1);
  });

  testWidgets("polling disables the buttons and shows the browser hint", (WidgetTester tester) async {
    await pumpLogin(tester, state: _polling(browser: LoginBrowserLaunch.opened));

    final FilledButton github = tester.widget(find.widgetWithText(FilledButton, "Continue with GitHub"));
    expect(github.onPressed, isNull);
    expect(find.textContaining("browser"), findsOneWidget);
  });

  testWidgets("Cancel while waiting cancels the browser sign-in", (WidgetTester tester) async {
    when(() => cubit.cancel()).thenAnswer((_) async {});
    await pumpLogin(tester, state: _polling(browser: LoginBrowserLaunch.opened));

    await tester.tap(find.text("Cancel"));

    verify(() => cubit.cancel()).called(1);
  });

  testWidgets("success keeps the buttons disabled until the gate flips", (WidgetTester tester) async {
    await pumpLogin(tester, state: const LoginState.success());

    final FilledButton github = tester.widget(find.widgetWithText(FilledButton, "Continue with GitHub"));
    expect(github.onPressed, isNull);
  });

  testWidgets("timeout renders a retry message", (WidgetTester tester) async {
    await pumpLogin(tester, state: const LoginState.timeout());

    expect(find.textContaining("timed out"), findsOneWidget);
  });

  testWidgets("browser-open failure keeps waiting with its dedicated message", (WidgetTester tester) async {
    await pumpLogin(tester, state: _polling(browser: LoginBrowserLaunch.failed));

    expect(find.text("Couldn't open your browser."), findsOneWidget);
    expect(find.text("Cancel"), findsOneWidget);
  });

  testWidgets("a declined sign-in renders its dedicated message", (WidgetTester tester) async {
    await pumpLogin(tester, state: const LoginState.failed(reason: LoginFailedReason.declined));

    expect(find.textContaining("declined"), findsOneWidget);
  });
}
