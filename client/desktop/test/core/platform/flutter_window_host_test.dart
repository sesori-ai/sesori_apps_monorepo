import "dart:async";

import "package:flutter/foundation.dart" show TargetPlatform, debugDefaultTargetPlatformOverride;
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:nativeapi/nativeapi.dart" as native show Application, Brightness;
import "package:screen_retriever/screen_retriever.dart";
import "package:sesori_desktop/core/platform/flutter_window_host.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:window_manager/window_manager.dart";

const _minimumSize = WindowSize(width: 560, height: 480);
const ListenerId _listenerId = 7;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel terminationChannel = MethodChannel("sesori/termination/test");

  setUpAll(() {
    registerFallbackValue(native.Brightness.light);
    registerFallbackValue(TitleBarStyle.normal);
    registerFallbackValue(Size.zero.toNative());
    registerFallbackValue(Offset.zero.toNative());
  });

  late _MockWindow window;
  late _MockDisplayManager displayManager;
  late _MockApplication application;
  late _MockDisplay display;
  late FutureOr<void> Function(WindowEvent) listener;

  FlutterWindowHost createHost() => FlutterWindowHost.forTesting(
    findWindow: () => window,
    displayManager: displayManager,
    application: application,
    terminationChannel: terminationChannel,
  );

  /// Delivers [event] the way nativeapi does, to the listener the host added.
  void deliver({required WindowEvent event}) => listener(event);

  setUp(() {
    window = _MockWindow();
    displayManager = _MockDisplayManager();
    application = _MockApplication();
    display = _MockDisplay();
    when(() => window.addListener(any())).thenAnswer((invocation) {
      listener = invocation.positionalArguments.single as FutureOr<void> Function(WindowEvent);
      return _listenerId;
    });
    when(() => window.removeListener(any())).thenReturn(true);
    when(() => window.isMinimized).thenReturn(false);
    when(() => window.size).thenReturn(const Size(720, 620).toNative());
    when(() => window.bounds).thenReturn(const Rect.fromLTWH(40, 60, 900, 700).toNative());
    when(() => application.setDockIconVisible(any())).thenReturn(true);
    when(() => application.setBrightness(any())).thenReturn(true);
    when(() => display.position).thenReturn(Offset.zero.toNative());
    when(() => display.size).thenReturn(const Size(1512, 982).toNative());
    when(() => display.workArea).thenReturn(const Rect.fromLTWH(0, 24, 1512, 958).toNative());
    when(displayManager.getAll).thenReturn(<Display>[display]);
    when(displayManager.getPrimary).thenReturn(display);
    when(displayManager.getCursorPosition).thenReturn(const Offset(300, 400).toNative());
  });

  test("initializes the default native window and emits typed close requests", () async {
    final host = createHost();
    addTearDown(host.dispose);
    final request = _MockEventRequest();
    when(request.cancel).thenReturn(true);

    await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);
    final event = host.events.first;
    deliver(event: WindowCloseRequestedEvent(windowId: 1, request: request));

    verifyInOrder(<void Function()>[
      () => window.addListener(any()),
      () => window.setSize(const Size(720, 620).toNative(), false),
      // Centred in the work area of the display under the cursor.
      () => window.position = const Offset(396, 193).toNative(),
      () => window.minimumSize = const Size(560, 480).toNative(),
      () => window.title = "Sesori",
      () => window.isVisibleInTaskbar = true,
      () => application.setDockIconVisible(true),
      () => window.show(),
      () => window.focus(),
    ]);
    verify(request.cancel).called(1);
    expect(host.currentState, WindowHostState.focused);
    expect(await event, WindowHostEvent.closeRequested);
  });

  test("relays the macOS runner's quit requests until disposed", () async {
    Future<ByteData?> runnerCall({required String method}) {
      final Completer<ByteData?> reply = Completer<ByteData?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        terminationChannel.name,
        terminationChannel.codec.encodeMethodCall(MethodCall(method)),
        reply.complete,
      );
      return reply.future;
    }

    final host = createHost();
    await host.initialize(hidden: true, initialBounds: null, minimumSize: _minimumSize);
    // Before the exit owner listens, the runner is told to quit on its own.
    final ByteData? beforeListening = await runnerCall(method: "quitRequested");
    final events = <WindowHostEvent>[];
    host.events.listen(events.add);

    final ByteData? handled = await runnerCall(method: "quitRequested");
    final ByteData? unknown = await runnerCall(method: "somethingElse");
    await host.dispose();
    final ByteData? afterDispose = await runnerCall(method: "quitRequested");

    expect(events, <WindowHostEvent>[WindowHostEvent.quitRequested]);
    expect(beforeListening, isNull);
    expect(handled, isNotNull);
    expect(unknown, isNull);
    expect(afterDispose, isNull);
  });

  test("applies restored bounds before the first visible show", () async {
    final host = createHost();
    addTearDown(host.dispose);
    const bounds = WindowBounds(left: 80, top: 90, width: 1000, height: 760);

    await host.initialize(hidden: false, initialBounds: bounds, minimumSize: _minimumSize);

    verifyInOrder(<void Function()>[
      () => window.setSize(const Size(1000, 760).toNative(), false),
      () => window.bounds = const Rect.fromLTWH(80, 90, 1000, 760).toNative(),
      () => window.isVisibleInTaskbar = true,
      () => window.show(),
      () => window.focus(),
    ]);
    verifyNever(() => window.position = any());
    verifyNever(window.center);
  });

  test("centres on the primary display when no display is under the cursor", () async {
    when(displayManager.getCursorPosition).thenReturn(const Offset(-500, -500).toNative());
    when(() => display.workArea).thenReturn(const Rect.fromLTWH(1512, 0, 1920, 1040).toNative());
    final host = createHost();
    addTearDown(host.dispose);

    await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);

    verify(() => window.position = const Offset(2112, 210).toNative()).called(1);
  });

  test("hidden initialization never shows or focuses the window", () async {
    final host = createHost();
    addTearDown(host.dispose);

    await host.initialize(hidden: true, initialBounds: null, minimumSize: _minimumSize);

    verifyInOrder(<void Function()>[
      () => window.isVisibleInTaskbar = false,
      () => application.setDockIconVisible(false),
      () => window.hide(),
    ]);
    verifyNever(window.show);
    verifyNever(window.focus);
    expect(host.currentState, WindowHostState.hidden);
  });

  test("fails when the native window cannot be found", () async {
    final host = FlutterWindowHost.forTesting(
      findWindow: () => null,
      displayManager: displayManager,
      application: application,
      terminationChannel: terminationChannel,
    );
    addTearDown(host.dispose);

    await expectLater(
      host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize),
      throwsStateError,
    );
  });

  test("translates bounds and attached display work areas", () async {
    final host = createHost();
    addTearDown(host.dispose);
    await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);
    when(() => window.bounds).thenReturn(const Rect.fromLTWH(-20, 30, 860, 640).toNative());

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

    verify(() => window.bounds = const Rect.fromLTWH(10, 20, 900, 700).toNative()).called(1);
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

    deliver(event: WindowMovedEvent(windowId: 1, newPosition: Offset.zero.toNative()));
    deliver(event: WindowResizedEvent(windowId: 1, newSize: const Size(800, 600).toNative()));
    deliver(event: const WindowBlurredEvent(windowId: 1));
    // Leaving the maximized state is a restore too, and changes nothing.
    deliver(event: const WindowRestoredEvent(windowId: 1));
    deliver(event: const WindowMinimizedEvent(windowId: 1));
    deliver(event: const WindowFocusedEvent(windowId: 1));
    deliver(event: const WindowRestoredEvent(windowId: 1));
    deliver(event: const WindowFocusedEvent(windowId: 1));

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

  test("show restores and focuses the window and hide updates visibility", () async {
    final host = createHost();
    addTearDown(host.dispose);
    await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);
    clearInteractions(window);
    clearInteractions(application);

    await host.hide();
    expect(host.currentState, WindowHostState.hidden);
    when(() => window.isMinimized).thenReturn(true);
    await host.show();
    expect(host.currentState, WindowHostState.focused);

    verifyInOrder(<void Function()>[
      () => window.hide(),
      () => window.isVisibleInTaskbar = false,
      () => application.setDockIconVisible(false),
      () => window.isVisibleInTaskbar = true,
      () => application.setDockIconVisible(true),
      () => window.restore(),
      () => window.show(),
      () => window.focus(),
    ]);
  });

  test("only macOS hides the title bar, and it keeps its traffic lights", () async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    Future<void> initializeOn({required TargetPlatform platform}) async {
      debugDefaultTargetPlatformOverride = platform;
      final host = createHost();
      addTearDown(host.dispose);
      await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);
    }

    await initializeOn(platform: TargetPlatform.macOS);
    verifyInOrder(<void Function()>[
      () => window.titleBarStyle = TitleBarStyle.hidden,
      () => window.isWindowControlButtonsVisible = true,
    ]);
    clearInteractions(window);
    // Windows and Linux keep their native chrome.
    await initializeOn(platform: TargetPlatform.windows);
    await initializeOn(platform: TargetPlatform.linux);
    verifyNever(() => window.titleBarStyle = any());
    verifyNever(() => window.isWindowControlButtonsVisible = any());
  });

  test("drags, zooms and sets the chrome's brightness through the native window", () async {
    final host = createHost();
    addTearDown(host.dispose);
    await expectLater(host.startDragging(), throwsStateError);
    await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);

    await host.startDragging();
    when(() => window.isMaximized).thenReturn(false);
    await host.toggleZoom();
    when(() => window.isMaximized).thenReturn(true);
    await host.toggleZoom();
    await host.setBrightness(brightness: WindowBrightness.dark);

    verifyInOrder(<void Function()>[
      () => window.startDragging(),
      () => window.maximize(),
      () => window.unmaximize(),
      () => application.setBrightness(native.Brightness.dark),
    ]);
  });

  test("failed initialization removes its close listener and restores the taskbar entry", () async {
    final host = createHost();
    when(() => window.setSize(any(), any())).thenThrow(StateError("native window unavailable"));

    await expectLater(host.initialize(hidden: true, initialBounds: null, minimumSize: _minimumSize), throwsStateError);

    verify(() => window.removeListener(_listenerId)).called(1);
    verify(() => window.isVisibleInTaskbar = true).called(1);
    verify(() => application.setDockIconVisible(true)).called(1);
    await host.dispose();
  });

  test("dispose removes its close listener", () async {
    final host = createHost();
    await host.initialize(hidden: false, initialBounds: null, minimumSize: _minimumSize);

    await host.dispose();

    verify(() => window.removeListener(_listenerId)).called(1);
  });
}

class _MockWindow() extends Mock implements Window;

class _MockDisplayManager() extends Mock implements DisplayManager;

class _MockDisplay() extends Mock implements Display;

class _MockApplication() extends Mock implements native.Application;

class _MockEventRequest() extends Mock implements EventRequest;
