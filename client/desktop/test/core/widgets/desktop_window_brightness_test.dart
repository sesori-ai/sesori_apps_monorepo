import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/core/widgets/desktop_window_brightness.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

void main() {
  late _MockWindowHost windowHost;

  setUpAll(() => registerFallbackValue(WindowBrightness.light));
  setUp(() {
    windowHost = _MockWindowHost();
    when(() => windowHost.setBrightness(brightness: any(named: "brightness"))).thenAnswer((_) async {});
  });

  Widget app({required ThemeMode mode}) => MaterialApp(
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    themeMode: mode,
    builder: (context, child) => DesktopWindowBrightness(
      windowHost: windowHost,
      child: child ?? const SizedBox.shrink(),
    ),
    home: const SizedBox.shrink(),
  );

  testWidgets("the native chrome follows the app's effective brightness, pushed once per change", (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(app(mode: ThemeMode.light));
    verify(() => windowHost.setBrightness(brightness: WindowBrightness.light)).called(1);

    await tester.pumpWidget(app(mode: ThemeMode.dark));
    await tester.pumpAndSettle();
    verify(() => windowHost.setBrightness(brightness: WindowBrightness.dark)).called(1);

    // System resolves against the OS. The host keeps whatever was forced last,
    // so an OS switch has to be pushed like any other change.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpWidget(app(mode: ThemeMode.system));
    await tester.pumpAndSettle();
    verifyNever(() => windowHost.setBrightness(brightness: any(named: "brightness")));

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    verify(() => windowHost.setBrightness(brightness: WindowBrightness.light)).called(1);
    verifyNever(() => windowHost.setBrightness(brightness: WindowBrightness.dark));
  });

  testWidgets("a host failure is logged instead of breaking the app", (tester) async {
    when(
      () => windowHost.setBrightness(brightness: any(named: "brightness")),
    ).thenAnswer((_) async => throw StateError("window is gone"));

    await tester.pumpWidget(app(mode: ThemeMode.light));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

class _MockWindowHost() extends Mock implements WindowHost;
