import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/theme/sesori_light_theme.dart";
import "package:sesori_mobile/core/widgets/connection_overlay.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";

import "../../helpers/test_helpers.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);

  late BehaviorSubject<ConnectionStatus> statusStream;
  late MockConnectionService mockConnectionService;
  late MockAuthSession mockAuthSession;

  setUp(() {
    statusStream = BehaviorSubject<ConnectionStatus>.seeded(
      const ConnectionStatus.disconnected(),
    );
    mockConnectionService = MockConnectionService();
    mockAuthSession = MockAuthSession();

    when(() => mockConnectionService.status).thenAnswer((_) => statusStream.stream);
    when(() => mockConnectionService.currentStatus).thenReturn(statusStream.value);
    when(() => mockAuthSession.logoutCurrentDevice()).thenAnswer((_) async {});

    if (GetIt.I.isRegistered<ConnectionService>()) {
      GetIt.I.unregister<ConnectionService>();
    }
    if (GetIt.I.isRegistered<AuthSession>()) {
      GetIt.I.unregister<AuthSession>();
    }

    GetIt.I.registerLazySingleton<ConnectionService>(() => mockConnectionService);
    GetIt.I.registerLazySingleton<AuthSession>(() => mockAuthSession);
  });

  tearDown(() async {
    await statusStream.close();
    await GetIt.I.reset();
  });

  testWidgets("connection lost overlay uses scrim without blur", (tester) async {
    const config = ServerConnectionConfig(
      relayHost: "relay.example.com",
      authToken: "token",
    );
    statusStream.add(const ConnectionStatus.connectionLost(config: config));
    when(() => mockConnectionService.currentStatus).thenReturn(
      const ConnectionStatus.connectionLost(config: config),
    );

    final router = GoRouter(
      routes: [
        GoRoute(
          path: "/",
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: sesoriLightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ConnectionOverlay(
          router: router,
          child: const Scaffold(
            body: Text("content"),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text("content"), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsWidgets);
  });
}
