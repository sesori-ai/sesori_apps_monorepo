import "dart:ui" show Offset, Rect, Size;

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:screen_retriever/screen_retriever.dart";
import "package:sesori_desktop/core/platform/flutter_window_host.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:window_manager/window_manager.dart";

const _minimumSize = WindowSize(width: 560, height: 480);

void main() {
  setUpAll(() {
    registerFallbackValue(const WindowOptions());
    registerFallbackValue(Rect.zero);
  });

  late _MockWindowManager manager;
  late _MockScreenRetriever screenRetriever;

  FlutterWindowHost createHost() => FlutterWindowHost.forTesting(
    manager: manager,
    screenRetriever: screenRetriever,
  );

  setUp(() {
    manager = _MockWindowManager();
    screenRetriever = _MockScreenRetriever();
    when(manager.ensureInitialized).thenAnswer((_) async {});
    when(() => manager.setPreventClose(any())).thenAnswer((_) async {});
    when(() => manager.waitUntilReadyToShow(any())).thenAnswer((_) async {});
    when(() => manager.setBounds(any())).thenAnswer((_) async {});
    when(manager.getBounds).thenAnswer((_) async => const Rect.fromLTWH(40, 60, 900, 700));
    when(manager.show).thenAnswer((_) async {});
    when(manager.focus).thenAnswer((_) async {});
    when(() => manager.setSkipTaskbar(any())).thenAnswer((_) async {});
    when(manager.hide).thenAnswer((_) async {});
    when(screenRetriever.getAllDisplays).thenAnswer(
      (_) async => const <Display>[
        Display(
          id: "main",
          size: Size(1512, 982),
          visiblePosition: Offset(0, 24),
          visibleSize: Size(1512, 958),
        ),
      ],
    );
  });

  test("initializes the default native window and emits typed close requests", () async {
    final host = createHost();
    addTearDown(host.dispose);

    await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);
    final options = verify(() => manager.waitUntilReadyToShow(captureAny())).captured.single as WindowOptions;
    final event = host.events.first;
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
    expect(options.center, isTrue);
    expect(options.title, "Sesori");
    expect(host.currentState, WindowHostState.focused);
    expect(await event, WindowHostEvent.closeRequested);
  });

  test("applies restored bounds before the first visible show", () async {
    final host = createHost();
    addTearDown(host.dispose);
    const bounds = WindowBounds(left: 80, top: 90, width: 1000, height: 760);

    await host.initialize(hidden: false, initialBounds: bounds, minimumSize: _minimumSize);

    final options = verify(() => manager.waitUntilReadyToShow(captureAny())).captured.single as WindowOptions;
    expect(options.size, const Size(1000, 760));
    expect(options.center, isFalse);
    verifyInOrder(<void Function()>[
      () => manager.setBounds(const Rect.fromLTWH(80, 90, 1000, 760)),
      () => manager.setSkipTaskbar(false),
      () => manager.show(),
      () => manager.focus(),
    ]);
  });

  test("hidden initialization never shows or focuses the window", () async {
    final host = createHost();
    addTearDown(host.dispose);

    await host.initialize(hidden: true, initialBounds: null, minimumSize: _minimumSize);

    verifyInOrder(<void Function()>[
      () => manager.setSkipTaskbar(true),
      () => manager.hide(),
    ]);
    verifyNever(manager.show);
    verifyNever(manager.focus);
    expect(host.currentState, WindowHostState.hidden);
  });

  test("translates bounds and attached display work areas", () async {
    final host = createHost();
    addTearDown(host.dispose);
    await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);
    clearInteractions(manager);
    when(manager.getBounds).thenAnswer((_) async => const Rect.fromLTWH(-20, 30, 860, 640));
    when(() => manager.setBounds(any())).thenAnswer((_) async {});

    expect(
      await host.getBounds(),
      const WindowBounds(left: -20, top: 30, width: 860, height: 640),
    );
    await host.setBounds(bounds: const WindowBounds(left: 10, top: 20, width: 900, height: 700));
    expect(
      await host.getDisplayBounds(),
      const <WindowBounds>[
        WindowBounds(left: 0, top: 24, width: 1512, height: 958),
      ],
    );

    verify(() => manager.setBounds(const Rect.fromLTWH(10, 20, 900, 700))).called(1);
  });

  test("emits move and resize events plus focus and visibility states", () async {
    final host = createHost();
    addTearDown(host.dispose);
    await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);
    final events = <WindowHostEvent>[];
    final states = <WindowHostState>[];
    final eventSubscription = host.events.listen(events.add);
    final stateSubscription = host.states.listen(states.add);
    addTearDown(eventSubscription.cancel);
    addTearDown(stateSubscription.cancel);

    host.onWindowMove();
    host.onWindowResize();
    host.onWindowBlur();
    host.onWindowMinimize();
    host.onWindowFocus();
    host.onWindowRestore();
    host.onWindowFocus();

    expect(events, <WindowHostEvent>[WindowHostEvent.moved, WindowHostEvent.resized]);
    expect(
      states,
      <WindowHostState>[
        WindowHostState.unfocused,
        WindowHostState.hidden,
        WindowHostState.unfocused,
        WindowHostState.focused,
      ],
    );
  });

  test("show focuses the restored window and hide updates visibility", () async {
    final host = createHost();
    addTearDown(host.dispose);
    await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);
    clearInteractions(manager);

    await host.hide();
    expect(host.currentState, WindowHostState.hidden);
    await host.show();
    expect(host.currentState, WindowHostState.focused);

    verifyInOrder(<void Function()>[
      () => manager.hide(),
      () => manager.setSkipTaskbar(true),
      () => manager.setSkipTaskbar(false),
      () => manager.show(),
      () => manager.focus(),
    ]);
  });

  test("failed initialization restores native close handling and removes its listener", () async {
    final host = createHost();
    when(() => manager.waitUntilReadyToShow(any())).thenThrow(StateError("native window unavailable"));

    await expectLater(host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize), throwsStateError);

    verify(() => manager.removeListener(host)).called(1);
    verify(() => manager.setPreventClose(false)).called(1);
    await host.dispose();
  });

  test("dispose removes its listener and restores native close behavior", () async {
    final host = createHost();
    await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);

    await host.dispose();

    verify(() => manager.removeListener(host)).called(1);
    verify(() => manager.setPreventClose(false)).called(1);
  });
}

class _MockWindowManager() extends Mock implements WindowManager;

class _MockScreenRetriever() extends Mock implements ScreenRetriever;
