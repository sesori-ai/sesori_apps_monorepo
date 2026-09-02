import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../support/bridge_id_storage.dart";

void main() {
  group("BridgeControlCubit", () {
    late _FakeBridgeProcessService processService;
    late BridgeStatusTracker statusTracker;
    late _FakeSystemTray systemTray;
    late _FakeWindowHost windowHost;
    late _FakeDesktopApplicationTerminator applicationTerminator;
    late _FakeBridgeProcessLogRepository logRepository;
    late _FakeDesktopInstanceService instanceService;
    late _FakeDesktopBridgeTakeoverOrchestrator takeoverOrchestrator;
    late DesktopLogoutTracker logoutTracker;
    late _FakeUrlLauncher urlLauncher;
    late _FakeLaunchAtLogin launchAtLogin;
    late BridgeControlCubit cubit;

    setUp(() {
      processService = _FakeBridgeProcessService();
      statusTracker = BridgeStatusTracker(bridgeIdStorage: MemoryBridgeIdStorage());
      systemTray = _FakeSystemTray();
      windowHost = _FakeWindowHost();
      applicationTerminator = _FakeDesktopApplicationTerminator();
      logRepository = _FakeBridgeProcessLogRepository();
      instanceService = _FakeDesktopInstanceService();
      takeoverOrchestrator = _FakeDesktopBridgeTakeoverOrchestrator();
      logoutTracker = DesktopLogoutTracker();
      urlLauncher = _FakeUrlLauncher();
      launchAtLogin = _FakeLaunchAtLogin();
      cubit = BridgeControlCubit(
        processService: processService,
        statusTracker: statusTracker,
        systemTray: systemTray,
        windowHost: windowHost,
        applicationTerminator: applicationTerminator,
        logRepository: logRepository,
        instanceService: instanceService,
        takeoverOrchestrator: takeoverOrchestrator,
        logoutTracker: logoutTracker,
        urlLauncher: urlLauncher,
        launchAtLogin: launchAtLogin,
        hiddenLaunch: false,
      );
    });

    tearDown(() async {
      await cubit.close();
      await processService.disposeFake();
      await statusTracker.dispose();
      await systemTray.disposeFake();
      await windowHost.disposeFake();
      await instanceService.disposeFake();
      await logoutTracker.dispose();
    });

    test("initializes a typed tray menu and reacts to process/status snapshots", () async {
      await cubit.initialize();

      expect(cubit.state.trayAvailability, SystemTrayAvailability.available);
      expect(_textLabels(menu: systemTray.menus.last), containsAll(<String>["Bridge: Off", "Active sessions: 0"]));
      expect(_command(menu: systemTray.menus.last, command: SystemTrayCommand.openWindow).label, "Open Sesori");
      expect(_command(menu: systemTray.menus.last, command: SystemTrayCommand.toggleBridge).label, "Turn Bridge On");
      expect(cubit.state.launchAtLoginEnabled, isFalse);
      expect(
        _command(menu: systemTray.menus.last, command: SystemTrayCommand.toggleLaunchAtLogin).label,
        "Enable Launch at Login",
      );

      statusTracker.markHelperConnected();
      statusTracker.applyStatus(
        status: const ControlStatus(
          relay: ControlRelayConnectionState.connected,
          plugin: ControlPluginHealthState.degraded,
          activeSessionCount: 3,
        ),
      );
      processService.emit(
        state: const BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
      );
      await pumpEventQueue(times: 2);

      expect(
        _textLabels(menu: systemTray.menus.last),
        containsAll(<String>["Bridge: Degraded", "Active sessions: 3"]),
      );
      expect(_command(menu: systemTray.menus.last, command: SystemTrayCommand.toggleBridge).label, "Turn Bridge Off");
    });

    test("exposes and handles Take Over for local bridge contention", () async {
      processService.emit(
        state: const BridgeProcessContention(),
        desiredState: BridgeProcessDesiredState.on,
      );
      await cubit.initialize();

      expect(_command(menu: systemTray.menus.last, command: SystemTrayCommand.takeOver).label, "Take Over");

      systemTray.emit(command: SystemTrayCommand.takeOver);
      await pumpEventQueue(times: 2);

      expect(takeoverOrchestrator.takeOverCalls, 1);
    });

    test("exposes Take Over when the relay was displaced", () async {
      statusTracker.markHelperConnected();
      statusTracker.applyStatus(
        status: const ControlStatus(
          relay: ControlRelayConnectionState.takenOver,
          plugin: ControlPluginHealthState.healthy,
          activeSessionCount: 0,
        ),
      );
      processService.emit(
        state: const BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
      );
      await cubit.initialize();

      expect(_command(menu: systemTray.menus.last, command: SystemTrayCommand.takeOver).label, "Take Over");
    });

    test("toggle launch-at-login updates the menu only after registration succeeds", () async {
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.toggleLaunchAtLogin);
      await pumpEventQueue(times: 2);

      expect(launchAtLogin.enableCalls, 1);
      expect(launchAtLogin.disableCalls, 0);
      expect(cubit.state.launchAtLoginEnabled, isTrue);
      expect(
        _command(menu: systemTray.menus.last, command: SystemTrayCommand.toggleLaunchAtLogin).label,
        "Disable Launch at Login",
      );

      systemTray.emit(command: SystemTrayCommand.toggleLaunchAtLogin);
      await pumpEventQueue(times: 2);
      expect(launchAtLogin.disableCalls, 1);
      expect(cubit.state.launchAtLoginEnabled, isFalse);
    });

    test("failed launch-at-login registration remains retryable", () async {
      launchAtLogin.enableError = StateError("login item unavailable");
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.toggleLaunchAtLogin);
      await pumpEventQueue(times: 2);

      expect(launchAtLogin.enableCalls, 1);
      expect(cubit.state.launchAtLoginEnabled, isFalse);
      expect(
        _command(menu: systemTray.menus.last, command: SystemTrayCommand.toggleLaunchAtLogin).label,
        "Enable Launch at Login",
      );
    });

    test("hidden launch shows the window when tray availability is unavailable", () async {
      await cubit.close();
      systemTray.availability = SystemTrayAvailability.unavailable;
      final BridgeControlCubit hiddenCubit = BridgeControlCubit(
        processService: processService,
        statusTracker: statusTracker,
        systemTray: systemTray,
        windowHost: windowHost,
        applicationTerminator: applicationTerminator,
        logRepository: logRepository,
        instanceService: instanceService,
        takeoverOrchestrator: takeoverOrchestrator,
        logoutTracker: logoutTracker,
        urlLauncher: urlLauncher,
        launchAtLogin: launchAtLogin,
        hiddenLaunch: true,
      );
      addTearDown(hiddenCubit.close);

      await hiddenCubit.initialize();

      expect(windowHost.showCalls, 1);
      expect(hiddenCubit.state.trayAvailability, SystemTrayAvailability.unavailable);
    });

    test("reports window-only fallback when no usable tray host exists", () async {
      systemTray.availability = SystemTrayAvailability.unavailable;

      await cubit.initialize();

      expect(cubit.state.trayAvailability, SystemTrayAvailability.unavailable);
      expect(systemTray.setMenuCalls, 0);
      expect(applicationTerminator.exitCodes, isEmpty);
    });

    test("reports window-only fallback when tray initialization throws", () async {
      systemTray.initializeError = StateError("tray plugin unavailable");

      await cubit.initialize();

      expect(cubit.state.trayAvailability, SystemTrayAvailability.unavailable);
      expect(applicationTerminator.exitCodes, isEmpty);
    });

    test("Open and native close route through the window host when the tray is available", () async {
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.openWindow);
      await pumpEventQueue(times: 2);
      expect(windowHost.showCalls, 1);

      windowHost.emit(event: WindowHostEvent.closeRequested);
      await pumpEventQueue(times: 2);
      expect(windowHost.hideCalls, 1);
      expect(applicationTerminator.exitCodes, isEmpty);
    });

    test("tray-backed close hides while a lifecycle operation is pending", () async {
      processService.emit(
        state: const BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
      );
      processService.stopGate = Completer<void>();
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue();
      windowHost.emit(event: WindowHostEvent.closeRequested);
      await pumpEventQueue();

      expect(cubit.state.activity, BridgeControlActivity.toggling);
      expect(windowHost.hideCalls, 1);
      processService.stopGate!.complete();
      await pumpEventQueue(times: 2);
    });

    test("no-tray close waits for a lifecycle operation before safe Quit", () async {
      systemTray.availability = SystemTrayAvailability.unavailable;
      processService.emit(
        state: const BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
      );
      processService.stopGate = Completer<void>();
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue();
      windowHost.emit(event: WindowHostEvent.closeRequested);
      await pumpEventQueue();
      expect(applicationTerminator.exitCodes, isEmpty);

      processService.stopGate!.complete();
      await pumpEventQueue(times: 3);
      expect(processService.stopCalls, 2);
      expect(applicationTerminator.exitCodes, <int>[0]);
    });

    test("logout status locks lifecycle controls until local auth clears", () async {
      await cubit.initialize();

      logoutTracker.markInProgress();
      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue();

      expect(cubit.state.activity, BridgeControlActivity.signingOut);
      expect(processService.startCalls, 0);

      logoutTracker.markIdle();
      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue(times: 2);
      expect(processService.startCalls, 1);
    });

    test("a second-launch focus request restores and focuses the window", () async {
      await cubit.initialize();

      instanceService.emitFocusRequest();
      await pumpEventQueue(times: 2);

      expect(windowHost.showCalls, 1);
    });

    test("native close safely quits instead of hiding without a tray host", () async {
      systemTray.availability = SystemTrayAvailability.unavailable;
      await cubit.initialize();

      windowHost.emit(event: WindowHostEvent.closeRequested);
      await pumpEventQueue(times: 2);

      expect(processService.stopCalls, 1);
      expect(windowHost.hideCalls, 0);
      expect(applicationTerminator.exitCodes, <int>[0]);
    });

    test("Open Logs launches the repository-owned local file URI", () async {
      await cubit.openLogs();

      expect(urlLauncher.launched, <Uri>[Uri.file("/tmp/sesori/bridge.log")]);
    });

    test("toggle commands drive desired On and Off through the process service", () async {
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue(times: 2);
      expect(processService.startCalls, 1);
      expect(processService.desiredState, BridgeProcessDesiredState.on);

      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue(times: 2);
      expect(processService.stopCalls, 1);
      expect(processService.desiredState, BridgeProcessDesiredState.off);
      expect(instanceService.writes, <BridgeProcessDesiredState>[
        BridgeProcessDesiredState.on,
        BridgeProcessDesiredState.off,
      ]);
    });

    test("explicit Start persists On and retries a stopped desired-On bridge", () async {
      processService.emit(
        state: const BridgeProcessStopped(),
        desiredState: BridgeProcessDesiredState.on,
      );
      await cubit.initialize();

      await cubit.startBridge();

      expect(processService.startCalls, 1);
      expect(processService.desiredState, BridgeProcessDesiredState.on);
      expect(instanceService.writes, <BridgeProcessDesiredState>[BridgeProcessDesiredState.on]);
    });

    test("a failed start leaves the next toggle targeted at retrying start", () async {
      processService.startError = StateError("spawn failed");
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue(times: 2);

      expect(processService.startCalls, 1);
      expect(processService.desiredState, BridgeProcessDesiredState.on);
      expect(_command(menu: systemTray.menus.last, command: SystemTrayCommand.toggleBridge).label, "Turn Bridge On");

      processService.startError = null;
      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue(times: 2);
      expect(processService.startCalls, 2);
      expect(processService.stopCalls, 0);
    });

    test("failed Off persistence leaves the helper running and the toggle retryable", () async {
      processService.emit(
        state: const BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
      );
      instanceService.writeError = StateError("application support is read-only");
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue(times: 2);

      expect(instanceService.writes, <BridgeProcessDesiredState>[BridgeProcessDesiredState.off]);
      expect(processService.stopCalls, 0);
      expect(processService.desiredState, BridgeProcessDesiredState.on);
      expect(_command(menu: systemTray.menus.last, command: SystemTrayCommand.toggleBridge).label, "Turn Bridge Off");

      instanceService.writeError = null;
      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue(times: 2);
      expect(processService.stopCalls, 1);
    });

    test("a failed stop leaves the next toggle targeted at retrying stop", () async {
      processService.emit(
        state: const BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
      );
      processService.stopError = StateError("stop failed");
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue(times: 2);

      expect(processService.stopCalls, 1);
      expect(processService.desiredState, BridgeProcessDesiredState.off);
      expect(_command(menu: systemTray.menus.last, command: SystemTrayCommand.toggleBridge).label, "Turn Bridge Off");

      processService.stopError = null;
      systemTray.emit(command: SystemTrayCommand.toggleBridge);
      await pumpEventQueue(times: 2);
      expect(processService.stopCalls, 2);
      expect(processService.startCalls, 0);
    });

    test("Quit preserves a persisted On intent while stopping the helper", () async {
      processService.emit(
        state: const BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
      );
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.quit);
      await pumpEventQueue(times: 2);

      expect(instanceService.cancelRestoreCalls, 1);
      expect(instanceService.writes, isEmpty);
      expect(processService.stopCalls, 1);
      expect(applicationTerminator.exitCodes, <int>[0]);
      expect(systemTray.disposeCalls, 1);
      expect(cubit.state.activity, BridgeControlActivity.quitting);
    });

    test("Quit terminates only after expected bridge stop completes", () async {
      processService.emit(
        state: const BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
      );
      processService.stopGate = Completer<void>();
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.quit);
      await pumpEventQueue(times: 2);

      expect(instanceService.cancelRestoreCalls, 1);
      expect(processService.stopCalls, 1);
      expect(applicationTerminator.exitCodes, isEmpty);
      expect(systemTray.disposeCalls, 0);

      processService.stopGate!.complete();
      await pumpEventQueue(times: 2);

      expect(systemTray.disposeCalls, 1);
      expect(windowHost.disposeCalls, 1);
      expect(instanceService.writes, isEmpty);
      expect(applicationTerminator.exitCodes, <int>[0]);
      expect(cubit.state.activity, BridgeControlActivity.quitting);
    });

    test("Quit leaves the app alive when expected bridge stop fails", () async {
      processService.emit(
        state: const BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
      );
      processService.stopError = StateError("bridge remained alive");
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.quit);
      await pumpEventQueue(times: 2);

      expect(applicationTerminator.exitCodes, isEmpty);
      expect(systemTray.disposeCalls, 0);
      expect(cubit.state.activity, BridgeControlActivity.idle);
    });
  });
}

List<String> _textLabels({required SystemTrayMenu menu}) =>
    menu.entries.whereType<SystemTrayTextItem>().map((item) => item.label).toList(growable: false);

SystemTrayCommandItem _command({required SystemTrayMenu menu, required SystemTrayCommand command}) =>
    menu.entries.whereType<SystemTrayCommandItem>().singleWhere((item) => item.command == command);

class _FakeBridgeProcessService() implements BridgeProcessService {
  final BehaviorSubject<BridgeProcessState> _states = BehaviorSubject<BridgeProcessState>.seeded(
    const BridgeProcessStopped(),
  );
  BridgeProcessDesiredState _desiredState = BridgeProcessDesiredState.off;
  int startCalls = 0;
  int stopCalls = 0;
  Object? startError;
  Completer<void>? stopGate;
  Object? stopError;

  @override
  ValueStream<BridgeProcessState> get states => _states.stream;

  @override
  BridgeProcessState get state => _states.value;

  @override
  BridgeProcessDesiredState get desiredState => _desiredState;

  @override
  Future<void> start() async {
    startCalls++;
    _desiredState = BridgeProcessDesiredState.on;
    final Object? failure = startError;
    if (failure != null) {
      _states.add(const BridgeProcessStopped());
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
    _states.add(const BridgeProcessRunning(pid: 42));
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _desiredState = BridgeProcessDesiredState.off;
    _states.add(const BridgeProcessStopping(pid: 42));
    final Object? failure = stopError;
    if (failure != null) {
      _states.add(const BridgeProcessRunning(pid: 42));
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
    final Completer<void>? gate = stopGate;
    if (gate != null) {
      await gate.future;
    }
    _states.add(const BridgeProcessStopped());
  }

  void emit({required BridgeProcessState state, required BridgeProcessDesiredState desiredState}) {
    _desiredState = desiredState;
    _states.add(state);
  }

  Future<void> disposeFake() => _states.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSystemTray() implements SystemTray {
  final StreamController<SystemTrayCommand> _commands = StreamController<SystemTrayCommand>.broadcast(sync: true);
  final List<SystemTrayMenu> menus = <SystemTrayMenu>[];
  SystemTrayAvailability availability = SystemTrayAvailability.available;
  Object? initializeError;
  int setMenuCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<SystemTrayCommand> get commands => _commands.stream;

  @override
  Future<SystemTrayAvailability> initialize({required SystemTrayMenu menu}) async {
    menus.add(menu);
    final Object? failure = initializeError;
    if (failure != null) {
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
    return availability;
  }

  @override
  Future<void> setMenu({required SystemTrayMenu menu}) async {
    setMenuCalls++;
    menus.add(menu);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  void emit({required SystemTrayCommand command}) {
    _commands.add(command);
  }

  Future<void> disposeFake() => _commands.close();
}

class _FakeWindowHost() implements WindowHost {
  final StreamController<WindowHostEvent> _events = StreamController<WindowHostEvent>.broadcast(sync: true);
  int showCalls = 0;
  int hideCalls = 0;
  int disposeCalls = 0;

  @override
  Stream<WindowHostEvent> get events => _events.stream;

  @override
  WindowHostState get currentState => WindowHostState.focused;

  @override
  Stream<WindowHostState> get states => const Stream<WindowHostState>.empty();

  @override
  Future<void> initialize({required bool hidden, required WindowBounds? initialBounds}) async {}

  @override
  Future<WindowBounds> getBounds() async => const WindowBounds(left: 0, top: 0, width: 720, height: 620);

  @override
  Future<void> setBounds({required WindowBounds bounds}) async {}

  @override
  Future<List<WindowBounds>> getDisplayBounds() async => const <WindowBounds>[];

  @override
  Future<void> show() async {
    showCalls++;
  }

  @override
  Future<void> hide() async {
    hideCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  void emit({required WindowHostEvent event}) {
    _events.add(event);
  }

  Future<void> disposeFake() => _events.close();
}

class _FakeBridgeProcessLogRepository() implements BridgeProcessLogRepository {
  @override
  Future<Uri> get logFileUri async => Uri.file("/tmp/sesori/bridge.log");
}

class _FakeDesktopInstanceService() implements DesktopInstanceService {
  final StreamController<void> _focusRequests = StreamController<void>.broadcast(sync: true);
  final List<BridgeProcessDesiredState> writes = <BridgeProcessDesiredState>[];
  int cancelRestoreCalls = 0;
  Object? writeError;

  @override
  Stream<void> get focusRequests => _focusRequests.stream;

  @override
  void cancelPendingBridgeRestore() {
    cancelRestoreCalls++;
  }

  @override
  Future<void> writeBridgeDesiredState({required BridgeProcessDesiredState state}) async {
    writes.add(state);
    final Object? error = writeError;
    if (error != null) {
      throw error;
    }
  }

  void emitFocusRequest() {
    _focusRequests.add(null);
  }

  Future<void> disposeFake() => _focusRequests.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDesktopBridgeTakeoverOrchestrator() implements DesktopBridgeTakeoverOrchestrator {
  int takeOverCalls = 0;
  Object? takeOverError;

  @override
  Future<void> takeOver() async {
    takeOverCalls++;
    final Object? error = takeOverError;
    if (error != null) {
      throw error;
    }
  }
}

class _FakeUrlLauncher() implements UrlLauncher {
  final List<Uri> launched = <Uri>[];

  @override
  Future<bool> launch(Uri url, {UrlLaunchMode mode = UrlLaunchMode.externalApp}) async {
    launched.add(url);
    return true;
  }
}

class _FakeDesktopApplicationTerminator() implements DesktopApplicationTerminator {
  final List<int> exitCodes = <int>[];

  @override
  void terminate({required int exitCode}) {
    exitCodes.add(exitCode);
  }
}

class _FakeLaunchAtLogin() implements LaunchAtLogin {
  bool enabled = false;
  int enableCalls = 0;
  int disableCalls = 0;
  Object? enableError;
  Object? disableError;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> enable() async {
    enableCalls++;
    final Object? error = enableError;
    if (error != null) {
      throw error;
    }
    enabled = true;
  }

  @override
  Future<void> disable() async {
    disableCalls++;
    final Object? error = disableError;
    if (error != null) {
      throw error;
    }
    enabled = false;
  }
}
