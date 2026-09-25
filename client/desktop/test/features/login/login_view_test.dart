import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/gestures.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/widgets/desktop_window_drag_area.dart";
import "package:sesori_desktop/features/login/login_brand_panel.dart";
import "package:sesori_desktop/features/login/login_screen.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _MockLoginCubit() extends MockCubit<LoginState> implements LoginCubit;

class _MockWindowHost() extends Mock implements WindowHost;

const _tagline = "Watch and steer your coding sessions from your desk or your phone.";
const _legal = "By signing in, you accept our Terms of Use and Privacy Policy.";
const _providerLabels = ["Continue with GitHub", "Continue with Apple", "Continue with Google"];

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
  late List<Uri> openedLinks;

  setUp(() {
    cubit = _MockLoginCubit();
    openedLinks = [];
  });

  Widget app({required Widget child}) => MaterialApp(
    theme: buildPregoThemeData(brightness: Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<LoginCubit>.value(value: cubit, child: child),
  );

  Widget view() => LoginView(
    openExternalLink: ({required url, required mode}) async {
      openedLinks.add(url);
      return true;
    },
  );

  Future<void> pumpLogin(WidgetTester tester, {required LoginState state, Size size = const Size(1200, 800)}) {
    whenListen(cubit, const Stream<LoginState>.empty(), initialState: state);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(app(child: view()));
  }

  PregoButtonsSolid button(WidgetTester tester, String label) =>
      tester.widget(find.widgetWithText(PregoButtonsSolid, label));

  group("layout", () {
    testWidgets("at 1200×800 the brand panel sits beside the sign-in column", (tester) async {
      await pumpLogin(tester, state: const LoginState.idle());

      expect(find.text(_tagline), findsOneWidget);
      expect(find.text("Sign in"), findsOneWidget);
      expect(find.text("Use the same account as on your phone."), findsOneWidget);
      for (final label in [..._providerLabels, "Sign in with email"]) {
        expect(button(tester, label).onPressed, isNotNull, reason: label);
      }
      expect(find.text(_legal, findRichText: true), findsOneWidget);
      // The brand panel carries the logo, so the column does not repeat it.
      expect(find.byType(SesoriLogo), findsOneWidget);
      expect(
        find.descendant(of: find.byType(LoginBrandPanel), matching: find.byType(SesoriLogo)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets("at 819×800 the panel folds and the logo tops the column", (tester) async {
      await pumpLogin(tester, state: const LoginState.idle(), size: const Size(819, 800));

      expect(find.text(_tagline), findsNothing);
      expect(find.byType(SesoriLogo), findsOneWidget);
      for (final label in _providerLabels) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text(_legal, findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("at the 560×480 minimum the column scrolls to the legal sentence", (tester) async {
      await pumpLogin(tester, state: const LoginState.idle(), size: const Size(560, 480));

      expect(find.text(_tagline), findsNothing);
      expect(tester.takeException(), isNull);
      final legal = find.text(_legal, findRichText: true);
      await tester.scrollUntilVisible(legal, 100);
      expect(tester.getRect(legal).bottom, lessThanOrEqualTo(480));
      expect(find.text("Sign in with email").hitTestable(), findsOneWidget);
    });

    testWidgets("crossing the breakpoint folds the panel and keeps what was typed", (tester) async {
      await pumpLogin(tester, state: const LoginState.idle());
      await tester.tap(find.text("Sign in with email"));
      await tester.pump();
      await tester.enterText(find.byType(EditableText).first, "dev@example.com");

      tester.view.physicalSize = const Size(700, 800);
      await tester.pumpAndSettle();

      expect(find.text(_tagline), findsNothing);
      expect(find.text("dev@example.com"), findsOneWidget);
    });

    testWidgets("the top band still drags the window at the minimum size", (tester) async {
      final windowHost = _MockWindowHost();
      when(windowHost.startDragging).thenAnswer((_) async {});
      whenListen(cubit, const Stream<LoginState>.empty(), initialState: const LoginState.idle());
      tester.view.physicalSize = const Size(560, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          child: DesktopWindowDragArea(
            windowHost: windowHost,
            height: PregoTopNavigation.barHeight,
            zoomOnDoubleClick: false,
            child: view(),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(280, 20), kind: PointerDeviceKind.mouse);
      await gesture.moveBy(const Offset(0, 60));
      await gesture.up();
      await tester.pump();

      verify(windowHost.startDragging).called(1);
    });
  });

  group("providers", () {
    for (final (label, provider) in [
      ("Continue with GitHub", AuthProvider.github),
      ("Continue with Apple", AuthProvider.apple),
      ("Continue with Google", AuthProvider.google),
    ]) {
      testWidgets("$label starts the browser sign-in", (tester) async {
        when(() => cubit.loginWithProvider(provider)).thenAnswer((_) async => true);
        await pumpLogin(tester, state: const LoginState.idle());

        await tester.tap(find.text(label));

        verify(() => cubit.loginWithProvider(provider)).called(1);
      });
    }

    testWidgets("the legal links open in the browser", (tester) async {
      await pumpLogin(tester, state: const LoginState.idle());

      await tester.tapOnText(find.textRange.ofSubstring("Terms of Use"));

      expect(openedLinks, [Uri.parse("https://sesori.com/terms")]);
    });

    testWidgets("polling disables every option and shows the browser hint", (tester) async {
      await pumpLogin(tester, state: _polling(browser: LoginBrowserLaunch.opened));

      for (final label in [..._providerLabels, "Sign in with email"]) {
        expect(button(tester, label).onPressed, isNull, reason: label);
      }
      expect(find.text("Confirm the sign-in in your browser to continue."), findsOneWidget);
    });

    testWidgets("Cancel while waiting cancels the browser sign-in", (tester) async {
      when(() => cubit.cancel()).thenAnswer((_) async {});
      await pumpLogin(tester, state: _polling(browser: LoginBrowserLaunch.opened));

      await tester.tap(find.text("Cancel"));

      verify(() => cubit.cancel()).called(1);
    });

    testWidgets("success keeps the buttons disabled until the gate flips", (tester) async {
      await pumpLogin(tester, state: const LoginState.success());

      expect(button(tester, "Continue with GitHub").onPressed, isNull);
    });

    testWidgets("timeout renders a retry message", (tester) async {
      await pumpLogin(tester, state: const LoginState.timeout());

      expect(find.text("Authorization timed out. Please try again."), findsOneWidget);
    });

    testWidgets("browser-open failure keeps waiting with its dedicated message", (tester) async {
      await pumpLogin(tester, state: _polling(browser: LoginBrowserLaunch.failed));

      expect(find.text("Could not open browser"), findsOneWidget);
      expect(find.text("Cancel"), findsOneWidget);
    });

    testWidgets("a declined sign-in renders its dedicated message", (tester) async {
      await pumpLogin(tester, state: const LoginState.failed(reason: LoginFailedReason.declined));

      expect(find.textContaining("declined"), findsOneWidget);
    });
  });

  group("email", () {
    // Stands in for the real cubit, which emits synchronously: dismissing a
    // failure updates [LoginCubit.state] before the next frame reads it.
    late LoginState current;

    void stubDismissableState(LoginState initial) {
      current = initial;
      final states = StreamController<LoginState>.broadcast();
      addTearDown(states.close);
      when(() => cubit.state).thenAnswer((_) => current);
      when(() => cubit.stream).thenAnswer((_) => states.stream);
      when(() => cubit.onDismissedLoginFailureError()).thenAnswer((_) {
        if (current is! LoginFailed) return;
        current = const LoginState.idle();
        states.add(current);
      });
    }

    Future<void> pumpDismissable(WidgetTester tester, {required LoginState state}) {
      stubDismissableState(state);
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(app(child: view()));
    }

    testWidgets("a provider failure does not follow the switch to email", (tester) async {
      await pumpDismissable(tester, state: const LoginState.failed(reason: LoginFailedReason.declined));
      expect(find.textContaining("declined"), findsOneWidget);

      await tester.tap(find.text("Sign in with email"));
      await tester.pump();

      expect(find.byType(EmailLoginForm), findsOneWidget);
      expect(find.byType(PregoInlineAlertsNotifications), findsNothing);
      expect(find.textContaining("declined"), findsNothing);
      verify(() => cubit.onDismissedLoginFailureError()).called(1);
    });

    testWidgets("an email failure does not outlive the form", (tester) async {
      await pumpDismissable(tester, state: const LoginState.idle());
      await tester.tap(find.text("Sign in with email"));
      await tester.pump();

      expect(find.text("Sign in with email"), findsOneWidget);
      expect(find.text("For accounts created with an email and password."), findsOneWidget);

      current = const LoginState.failed(reason: LoginFailedReason.unknown);
      await tester.pumpWidget(app(child: view()));
      expect(find.byType(PregoInlineAlertsNotifications), findsOneWidget);

      await tester.tap(find.text("Other ways to sign in"));
      await tester.pump();

      expect(find.byType(EmailLoginForm), findsNothing);
      expect(find.text("Continue with GitHub"), findsOneWidget);
      expect(find.text("Sign in failed. Please try again."), findsNothing);
      verify(() => cubit.onDismissedLoginFailureError()).called(2);
    });
  });
}
