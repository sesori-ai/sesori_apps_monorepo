import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:clock/clock.dart";
import "package:flutter/gestures.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/widgets/desktop_window_drag_area.dart";
import "package:sesori_desktop/features/login/login_brand_panel.dart";
import "package:sesori_desktop/features/login/login_screen.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _MockLoginCubit() extends MockCubit<LoginState> implements LoginCubit;

class _MockLastSignInProviderCubit() extends MockCubit<AuthProvider?> implements LastSignInProviderCubit;

class _MockWindowHost() extends Mock implements WindowHost;

class _MockAuthSession() extends Mock implements AuthSession;

class _MockInstallationAnalyticsService() extends Mock implements InstallationAnalyticsService;

const _tagline = "Watch and steer your coding sessions from your desk or your phone.";
const _legal = "By signing in, you accept our Terms of Use and Privacy Policy.";
const _providerLabels = ["Continue with GitHub", "Continue with Apple", "Continue with Google"];
const _authUrl = "https://auth.example.com/github";

/// A GitHub sign-in waiting on the browser, due to expire in 4:32. Widget
/// tests fake the clock, so the countdown moves only as far as the test pumps.
LoginState _polling({required LoginBrowserLaunch browser}) => LoginState.polling(
  handoff: LoginHandoff(
    provider: AuthProvider.github,
    oauth: OAuthHandoff(
      authUrl: Uri.parse(_authUrl),
      expiresAt: clock.now().add(const Duration(minutes: 4, seconds: 32)),
      deviceName: "Test Mac",
    ),
    browser: browser,
  ),
);

void main() {
  late _MockLoginCubit cubit;
  late StreamController<LoginState> cubitStates;
  late _MockLastSignInProviderCubit lastUsed;
  late List<Uri> openedLinks;

  setUp(() {
    cubit = _MockLoginCubit();
    // Synchronous, so an emitted state is already built by the next pump.
    cubitStates = StreamController<LoginState>.broadcast(sync: true);
    addTearDown(cubitStates.close);
    lastUsed = _MockLastSignInProviderCubit();
    whenListen(lastUsed, const Stream<AuthProvider?>.empty(), initialState: null);
    openedLinks = [];
  });

  Widget app({required Widget child}) => MaterialApp(
    theme: buildPregoThemeData(brightness: Brightness.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider<LoginCubit>.value(value: cubit),
        BlocProvider<LastSignInProviderCubit>.value(value: lastUsed),
      ],
      child: child,
    ),
  );

  Widget view() => LoginView(
    openExternalLink: ({required url, required mode}) async {
      openedLinks.add(url);
      return true;
    },
  );

  Future<void> pumpLogin(WidgetTester tester, {required LoginState state, Size size = const Size(1200, 800)}) {
    whenListen(cubit, cubitStates.stream, initialState: state);
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

    testWidgets("the tapped provider spins while its sign-in starts", (tester) async {
      when(() => cubit.loginWithProvider(AuthProvider.apple)).thenAnswer((_) async => true);
      await pumpLogin(tester, state: const LoginState.idle());

      await tester.tap(find.text("Continue with Apple"));
      cubitStates.add(const LoginState.authenticating());
      await tester.pump();

      expect(button(tester, "Continue with Apple").isLoading, isTrue);
      expect(button(tester, "Continue with GitHub").isLoading, isFalse);
      expect(button(tester, "Continue with GitHub").onPressed, isNull);
    });

    testWidgets("success keeps the buttons disabled until the gate flips", (tester) async {
      await pumpLogin(tester, state: const LoginState.success());

      expect(button(tester, "Continue with GitHub").onPressed, isNull);
    });

    for (final (state, title, message) in [
      (
        const LoginState.timeout(),
        "The sign-in link expired",
        "Nothing was confirmed in the browser within 5 minutes. Choose a way to sign in again.",
      ),
      (
        const LoginState.failed(reason: LoginFailedReason.declined),
        "Sign-in was declined",
        "The browser page did not confirm this sign-in. Choose a way to sign in again.",
      ),
      (
        const LoginState.failed(reason: LoginFailedReason.unknown),
        "Authentication failed",
        "Sign in failed. Please try again.",
      ),
    ]) {
      testWidgets("“$title” shows above the re-enabled buttons without moving them", (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpLogin(tester, state: const LoginState.idle());
        final github = find.widgetWithText(PregoButtonsSolid, "Continue with GitHub");
        final buttonsAt = tester.getRect(github);
        expect(find.semantics.byLabel("Sign in"), findsOne);

        cubitStates.add(state);
        await tester.pump();

        expect(find.text(title), findsOneWidget);
        expect(tester.getRect(find.text(message)).bottom, lessThan(buttonsAt.top));
        expect(tester.getRect(github), buttonsAt);
        for (final label in [..._providerLabels, "Sign in with email"]) {
          expect(button(tester, label).onPressed, isNotNull, reason: label);
        }
        // Screen readers reach the notice, not the heading it covers.
        expect(find.semantics.byLabel(title), findsOne);
        expect(find.semantics.byLabel("Sign in"), findsNothing);
        expect(find.semantics.byLabel("Use the same account as on your phone."), findsNothing);

        cubitStates.add(const LoginState.idle());
        await tester.pump();

        expect(find.text(title), findsNothing);
        expect(tester.getRect(github), buttonsAt);
        semantics.dispose();
      });
    }
  });

  group("browser handoff", () {
    testWidgets("waiting shows the handoff card in place of the provider list", (tester) async {
      await pumpLogin(tester, state: _polling(browser: LoginBrowserLaunch.opened));

      expect(find.text("Continue in your browser"), findsOneWidget);
      expect(
        find.text(
          "We opened GitHub sign-in in your browser. The page will ask you to confirm “Test Mac”. "
          "Come back here when it is done.",
        ),
        findsOneWidget,
      );
      expect(find.text("The link expires in 4:32"), findsOneWidget);
      for (final label in ["Open again", "Copy link", "Cancel and choose another way"]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final label in [..._providerLabels, "Sign in with email"]) {
        expect(find.text(label), findsNothing, reason: label);
      }
    });

    testWidgets("the countdown ticks every second and stops at zero", (tester) async {
      await pumpLogin(tester, state: _polling(browser: LoginBrowserLaunch.opened));

      await tester.pump(const Duration(seconds: 1));
      expect(find.text("The link expires in 4:31"), findsOneWidget);

      await tester.pump(const Duration(minutes: 4, seconds: 31));
      expect(find.text("The link expires in 0:00"), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text("The link expires in 0:00"), findsOneWidget);
    });

    testWidgets("a browser that fails to open offers the link and a retry", (tester) async {
      await pumpLogin(tester, state: _polling(browser: LoginBrowserLaunch.failed));

      expect(find.text("Couldn’t open your browser"), findsOneWidget);
      expect(
        find.text(
          "Copy the link, open it in any browser on this computer, and finish signing in there. "
          "We are still waiting.",
        ),
        findsOneWidget,
      );
      expect(find.text("The link expires in 4:32"), findsOneWidget);
      for (final label in ["Copy link", "Try again", "Cancel and choose another way"]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text("Open again"), findsNothing);
    });

    for (final (label, browser) in [
      ("Open again", LoginBrowserLaunch.opened),
      ("Try again", LoginBrowserLaunch.failed),
    ]) {
      testWidgets("$label reopens the sign-in page", (tester) async {
        when(() => cubit.reopenBrowser()).thenAnswer((_) async {});
        await pumpLogin(tester, state: _polling(browser: browser));

        await tester.tap(find.text(label));

        verify(() => cubit.reopenBrowser()).called(1);
      });
    }

    testWidgets("Copy link puts the sign-in link on the clipboard", (tester) async {
      final copied = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call case MethodCall(method: "Clipboard.setData", arguments: {"text": final String text})) {
          copied.add(text);
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpLogin(tester, state: _polling(browser: LoginBrowserLaunch.opened));

      await tester.tap(find.text("Copy link"));
      await tester.pump();

      expect(copied, [_authUrl]);
      expect(find.text("Link copied to clipboard"), findsOneWidget);
    });

    testWidgets("Cancel returns to the provider list", (tester) async {
      when(() => cubit.cancel()).thenAnswer((_) async => cubitStates.add(const LoginState.idle()));
      await pumpLogin(tester, state: _polling(browser: LoginBrowserLaunch.opened));

      await tester.tap(find.text("Cancel and choose another way"));
      await tester.pump();

      verify(() => cubit.cancel()).called(1);
      expect(find.text("Continue in your browser"), findsNothing);
      for (final label in [..._providerLabels, "Sign in with email"]) {
        expect(button(tester, label).onPressed, isNotNull, reason: label);
      }
    });
  });

  group("last used", () {
    Finder lastUsedIn(String label) =>
        find.descendant(of: find.widgetWithText(PregoButtonsSolid, label), matching: find.text("Last used"));

    testWidgets("no stored method marks nothing", (tester) async {
      await pumpLogin(tester, state: const LoginState.idle());

      expect(find.text("Last used"), findsNothing);
    });

    testWidgets("the provider this device signed in with last carries the chip", (tester) async {
      whenListen(lastUsed, const Stream<AuthProvider?>.empty(), initialState: AuthProvider.apple);
      await pumpLogin(tester, state: const LoginState.idle());

      expect(lastUsedIn("Continue with Apple"), findsOneWidget);
      expect(find.text("Last used"), findsOneWidget);
    });

    testWidgets("an email sign-in marks the email link instead", (tester) async {
      whenListen(lastUsed, const Stream<AuthProvider?>.empty(), initialState: AuthProvider.email);
      await pumpLogin(tester, state: const LoginState.idle());

      expect(
        find.descendant(
          of: find.widgetWithText(PregoButtonsSolid, "Sign in with email"),
          matching: find.byType(PregoTag),
        ),
        findsOneWidget,
      );
      expect(find.text("Last used"), findsOneWidget);
    });

    testWidgets("LoginScreen marks the provider the auth session stored", (tester) async {
      await getIt.reset();
      addTearDown(getIt.reset);
      final authSession = _MockAuthSession();
      when(authSession.lastSignedInProvider).thenAnswer((_) async => AuthProvider.google);
      final lifecycle = FakeLifecycleSource();
      addTearDown(lifecycle.close);
      getIt
        ..registerSingleton<AuthSession>(authSession)
        ..registerSingleton<OAuthFlowProvider>(MockOAuthFlowProvider())
        ..registerSingleton<UrlLauncher>(MockUrlLauncher())
        ..registerSingleton<LifecycleSource>(lifecycle)
        ..registerSingleton<InstallationAnalyticsService>(_MockInstallationAnalyticsService());
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildPregoThemeData(brightness: Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(lastUsedIn("Continue with Google"), findsOneWidget);
      expect(find.text("Last used"), findsOneWidget);
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
