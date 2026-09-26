import "package:flutter/gestures.dart" show PointerDeviceKind;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/app.dart";
import "package:sesori_desktop/core/di/injection.dart";
import "package:sesori_desktop/core/routing/desktop_router.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:theme_prego/module_prego.dart";

class _InMemorySecrets() implements SecureStorageRepository {
  final Map<SecretStorageKey, String> _values = {};

  @override
  Future<String?> read({required SecretStorageKey key}) async => _values[key];

  @override
  Future<void> write({required SecretStorageKey key, required String value}) async => _values[key] = value;

  @override
  Future<void> delete({required SecretStorageKey key}) async => _values.remove(key);

  @override
  Future<void> reset() async => _values.clear();
}

class _MockPersister() extends Mock implements PersisterRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets("cold start with no session lands on the login view", (WidgetTester tester) async {
    configureDesktopDependencies(
      router: desktopRouter,
      routerReady: desktopRouterReady,
    );
    // Keep widget behavior isolated from real application files/native keys.
    getIt.unregister<SecureStorageRepository>();
    getIt.registerLazySingleton<SecureStorageRepository>(_InMemorySecrets.new);
    final persister = _MockPersister();
    when(() => persister.readBool(key: BoolPreferenceKey.hasRegisteredBridges)).thenAnswer((_) async => null);
    when(() => persister.writeString(key: StringPreferenceKey.appearanceMode, value: "light")).thenAnswer((_) async {});
    getIt.unregister<PersisterRepository>();
    getIt.registerLazySingleton<PersisterRepository>(() => persister);
    final _UnavailableSystemTray systemTray = _UnavailableSystemTray();
    getIt.unregister<SystemTray>();
    getIt.registerLazySingleton<SystemTray>(() => systemTray);
    getIt.unregister<DesktopApplicationTerminator>();
    getIt.registerLazySingleton<DesktopApplicationTerminator>(_FakeApplicationTerminator.new);
    final _FakeWindowHost windowHost = _FakeWindowHost();
    getIt.unregister<WindowHost>();
    getIt.registerLazySingleton<WindowHost>(() => windowHost);
    getIt.unregister<LaunchAtLogin>();
    getIt.registerLazySingleton<LaunchAtLogin>(_FakeLaunchAtLogin.new);

    await tester.pumpWidget(
      const SesoriDesktopApp(
        hiddenLaunch: false,
        initialAppearance: AppearanceMode.dark,
        initialChatInputMode: ChatInputMode.voiceFirst,
      ),
    );
    await tester.pump();
    await tester.pump();
    await expectLater(desktopRouterReady, completes);

    expect(find.text("Continue with GitHub"), findsOneWidget);
    expect(find.text("Continue with Google"), findsOneWidget);
    expect(getIt<RouteSource>().currentRoute, AppRouteDef.projects);
    expect(systemTray.initializeCalls, 1);

    final scope = tester.widget<GlassAdaptiveScope>(find.byType(GlassAdaptiveScope));
    expect(scope.minQuality, GlassQuality.minimal);
    expect(scope.initialQuality, GlassQuality.standard);
    expect(scope.maxQuality, GlassQuality.standard);
    expect(scope.allowStepUp, isTrue);
    expect(scope.targetFrameMs, 16);
    expect(scope.onQualityChanged, isNotNull);

    final loginContext = tester.element(find.text("Continue with GitHub"));
    expect(PregoInteractionScope.of(loginContext), PregoInteractionMode.pointer);
    expect(MediaQuery.platformBrightnessOf(loginContext), Brightness.light);
    expect(GlassTheme.brightnessOf(loginContext), Brightness.dark);
    expect(windowHost.brightnessPushes, [WindowBrightness.dark]);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await loginContext.read<AppearanceCubit>().select(mode: AppearanceMode.light);
    await tester.pumpAndSettle();
    expect(GlassTheme.brightnessOf(loginContext), Brightness.light);
    expect(MediaQuery.platformBrightnessOf(loginContext), Brightness.dark);
    expect(windowHost.brightnessPushes, [WindowBrightness.dark, WindowBrightness.light]);

    // Signed out there is no cockpit shell, and the top of the window still moves it.
    await tester.dragFrom(const Offset(400, 20), const Offset(40, 0), kind: PointerDeviceKind.mouse);
    expect(windowHost.dragStarts, 1);
    // As macOS, where the app hides the title bar and moves the window itself.
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}

class _UnavailableSystemTray() implements SystemTray {
  int initializeCalls = 0;

  @override
  Stream<SystemTrayCommand> get commands => const Stream<SystemTrayCommand>.empty();

  @override
  Future<SystemTrayAvailability> initialize({required SystemTrayMenu menu}) async {
    initializeCalls++;
    return SystemTrayAvailability.unavailable;
  }

  @override
  Future<void> setMenu({required SystemTrayMenu menu}) async {}

  @override
  Future<void> dispose() async {}
}

class _FakeWindowHost() implements WindowHost {
  int dragStarts = 0;
  final List<WindowBrightness> brightnessPushes = <WindowBrightness>[];

  @override
  Stream<WindowHostEvent> get events => const Stream<WindowHostEvent>.empty();

  @override
  WindowHostState get currentState => WindowHostState.focused;

  @override
  Stream<WindowHostState> get states => const Stream<WindowHostState>.empty();

  @override
  Future<void> initialize({
    required bool hidden,
    required WindowBounds? initialBounds,
    required WindowSize minimumSize,
  }) async {}

  @override
  Future<WindowBounds> getBounds() async => const WindowBounds(left: 0, top: 0, width: 720, height: 620);

  @override
  Future<void> setBounds({required WindowBounds bounds}) async {}

  @override
  Future<List<WindowBounds>> getDisplayBounds() async => const <WindowBounds>[];

  @override
  Future<void> show() async {}

  @override
  Future<void> hide() async {}

  @override
  Future<void> startDragging() async => dragStarts++;

  @override
  Future<void> toggleZoom() async {}

  @override
  Future<void> setBrightness({required WindowBrightness brightness}) async => brightnessPushes.add(brightness);

  @override
  Future<void> dispose() async {}
}

class _FakeApplicationTerminator() implements DesktopApplicationTerminator {
  @override
  void terminate({required int exitCode}) {}
}

class _FakeLaunchAtLogin() implements LaunchAtLogin {
  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}
