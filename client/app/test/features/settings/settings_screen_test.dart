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
import "package:sesori_mobile/core/support_links.dart";
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

class _MockAppearanceStore extends Mock implements AppearanceStore {}

class _MockUrlLauncher extends Mock implements UrlLauncher {}

class _MockLegalRepository extends Mock implements LegalRepository {}

Widget _app({required AppearanceCubit appearance}) {
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

  return BlocProvider<AppearanceCubit>.value(
    value: appearance,
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// Gives the screen room to lay out every section, so rows below the fold are
/// tappable without scrolling.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late AppearanceCubit appearance;
  late _MockUrlLauncher urlLauncher;
  late _MockLegalRepository legalRepository;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(UrlLaunchMode.externalApp);
    registerFallbackValue(AppearanceMode.system);
    registerFallbackValue(LegalDocument.terms);
  });

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

    final store = _MockAppearanceStore();
    when(() => store.write(mode: any(named: "mode"))).thenAnswer((_) async {});
    appearance = AppearanceCubit(store: store, initialMode: AppearanceMode.system);

    urlLauncher = _MockUrlLauncher();
    when(() => urlLauncher.launch(any(), mode: any(named: "mode"))).thenAnswer((_) async => true);
    GetIt.instance.registerSingleton<UrlLauncher>(urlLauncher);

    legalRepository = _MockLegalRepository();
    GetIt.instance.registerSingleton<LegalRepository>(legalRepository);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets("profile row stays reachable without a cached account", (tester) async {
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    // Logout lives on the profile screen, so the row navigating there must
    // not depend on cached account metadata.
    await tester.tap(find.text("Profile"));
    await tester.pumpAndSettle();

    expect(find.text("profile-route"), findsOneWidget);
  });

  testWidgets("tapping a theme tile switches the appearance", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Dark"));
    await tester.pumpAndSettle();

    expect(appearance.state, AppearanceMode.dark);
  });

  testWidgets("the theme tiles announce as one mutually exclusive choice", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();

    // AppearanceMode.system is the seeded state, so System is the checked tile.
    expect(
      tester.getSemantics(find.text("System")),
      matchesSemantics(
        label: "System",
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(find.text("Light")),
      matchesSemantics(
        label: "Light",
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });

  testWidgets("legal rows open the document in a sheet, not a browser", (tester) async {
    _useTallSurface(tester);
    when(() => legalRepository.getMarkdown(document: any(named: "document")))
        .thenAnswer((_) async => ApiResponse.success("# Privacy Policy\n\nHow we handle your data."));

    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Privacy Policy"));
    await tester.pumpAndSettle();

    verify(() => legalRepository.getMarkdown(document: LegalDocument.privacy)).called(1);
    expect(find.text("How we handle your data."), findsOneWidget);
    verifyNever(() => urlLauncher.launch(any(), mode: any(named: "mode")));
  });

  testWidgets("a failed document load offers a retry that reloads it", (tester) async {
    _useTallSurface(tester);
    var attempt = 0;
    when(() => legalRepository.getMarkdown(document: any(named: "document"))).thenAnswer((_) async {
      attempt++;
      return attempt == 1
          ? ApiResponse.error(ApiError.dartHttpClient(Exception("offline")))
          : ApiResponse.success("# Terms of Service\n\nThe agreement text.");
    });

    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Terms of Service"));
    await tester.pumpAndSettle();

    expect(find.text("Connection failed — check your network and try again."), findsOneWidget);

    await tester.tap(find.text("Retry"));
    await tester.pumpAndSettle();

    expect(find.text("The agreement text."), findsOneWidget);
  });

  testWidgets("support rows hand off to the channel's own app", (tester) async {
    _useTallSurface(tester);
    await tester.pumpWidget(_app(appearance: appearance));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Discord"));
    await tester.pumpAndSettle();

    verify(
      () => urlLauncher.launch(
        Uri.parse(SupportLinks.discord),
        mode: UrlLaunchMode.externalApp,
      ),
    ).called(1);
  });
}
