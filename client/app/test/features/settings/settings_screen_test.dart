import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/settings/settings_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// An [AuthSession] with valid local tokens but no cached [AuthUser]: the
/// state splash leaves behind when `restoreLocalSession()` finds no stored
/// user, so `SettingsCubit.account` stays null.
class _StubAuthSession extends Mock implements AuthSession {
  final BehaviorSubject<AuthState> _authState = BehaviorSubject.seeded(const AuthState.unauthenticated());

  @override
  ValueStream<AuthState> get authStateStream => _authState.stream;

  @override
  AuthState get currentState => _authState.value;
}

class _MockNotificationRegistrationService extends Mock implements NotificationRegistrationService {}

Widget _app() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) => BlocProvider<ConnectionOverlayCubit>.value(
          value: StubConnectionOverlayCubit(),
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: "/settings/profile",
        builder: (context, state) => const Scaffold(body: Text("profile-route")),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: "Sesori",
      packageName: "com.sesori.app",
      version: "1.0.0",
      buildNumber: "1",
      buildSignature: "",
    );

    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<AuthSession>(_StubAuthSession());
    GetIt.instance.registerSingleton<NotificationRegistrationService>(
      _MockNotificationRegistrationService(),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets("profile row stays reachable without a cached account", (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Logout lives on the profile screen, so the row navigating there must
    // not depend on cached account metadata.
    await tester.tap(find.text("Profile"));
    await tester.pumpAndSettle();

    expect(find.text("profile-route"), findsOneWidget);
  });
}
