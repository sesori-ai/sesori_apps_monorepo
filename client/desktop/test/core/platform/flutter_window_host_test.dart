import "dart:ui" show Size;

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/core/platform/flutter_window_host.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:window_manager/window_manager.dart";

void main() {
  setUpAll(() {
    registerFallbackValue(const WindowOptions());
  });

  late _MockWindowManager manager;

  setUp(() {
    manager = _MockWindowManager();
    when(manager.ensureInitialized).thenAnswer((_) async {});
    when(() => manager.setPreventClose(any())).thenAnswer((_) async {});
    when(() => manager.waitUntilReadyToShow(any())).thenAnswer((_) async {});
    when(manager.show).thenAnswer((_) async {});
    when(manager.focus).thenAnswer((_) async {});
    when(() => manager.setSkipTaskbar(any())).thenAnswer((_) async {});
    when(manager.hide).thenAnswer((_) async {});
  });

  test("initializes the native window and emits typed close requests", () async {
    final FlutterWindowHost host = FlutterWindowHost.forTesting(manager: manager);
    addTearDown(host.dispose);

    await host.initialize(hidden: false);
    final WindowOptions options =
        verify(() => manager.waitUntilReadyToShow(captureAny())).captured.single as WindowOptions;
    final Future<WindowHostEvent> event = host.events.first;
    host.onWindowClose();

    verifyInOrder(<void Function()>[
      () => manager.ensureInitialized(),
      () => manager.addListener(host),
      () => manager.setPreventClose(true),
      () => manager.setSkipTaskbar(false),
      () => manager.show(),
      () => manager.focus(),
    ]);
    expect(options.size, const Size(720, 620));
    expect(options.minimumSize, const Size(560, 480));
    expect(options.title, "Sesori");
    expect(await event, WindowHostEvent.closeRequested);
  });

  test("hidden initialization never shows or focuses the window", () async {
    final FlutterWindowHost host = FlutterWindowHost.forTesting(manager: manager);
    addTearDown(host.dispose);

    await host.initialize(hidden: true);

    verifyInOrder(<void Function()>[
      () => manager.setSkipTaskbar(true),
      () => manager.hide(),
    ]);
    verifyNever(manager.show);
    verifyNever(manager.focus);
  });

  test("show focuses the restored window and hide delegates to the plugin", () async {
    final FlutterWindowHost host = FlutterWindowHost.forTesting(manager: manager);
    addTearDown(host.dispose);
    await host.initialize(hidden: false);
    clearInteractions(manager);
    when(manager.show).thenAnswer((_) async {});
    when(manager.focus).thenAnswer((_) async {});
    when(manager.hide).thenAnswer((_) async {});

    await host.show();
    await host.hide();

    verifyInOrder(<void Function()>[
      () => manager.setSkipTaskbar(false),
      () => manager.show(),
      () => manager.focus(),
      () => manager.hide(),
      () => manager.setSkipTaskbar(true),
    ]);
  });

  test("failed initialization restores native close handling and removes its listener", () async {
    final FlutterWindowHost host = FlutterWindowHost.forTesting(manager: manager);
    when(() => manager.waitUntilReadyToShow(any())).thenThrow(StateError("native window unavailable"));

    await expectLater(host.initialize(hidden: false), throwsStateError);

    verify(() => manager.removeListener(host)).called(1);
    verify(() => manager.setPreventClose(false)).called(1);
    await host.dispose();
  });

  test("dispose removes its listener and restores native close behavior", () async {
    final FlutterWindowHost host = FlutterWindowHost.forTesting(manager: manager);
    await host.initialize(hidden: false);

    await host.dispose();

    verify(() => manager.removeListener(host)).called(1);
    verify(() => manager.setPreventClose(false)).called(1);
  });
}

class _MockWindowManager() extends Mock implements WindowManager;
