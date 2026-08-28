import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("BridgeControlCubit", () {
    late _FakeBridgeProcessService processService;
    late BridgeStatusTracker statusTracker;
    late _FakeSystemTray systemTray;
    late _FakeDesktopApplicationTerminator applicationTerminator;
    late BridgeControlCubit cubit;

    setUp(() {
      processService = _FakeBridgeProcessService();
      statusTracker = BridgeStatusTracker();
      systemTray = _FakeSystemTray();
      applicationTerminator = _FakeDesktopApplicationTerminator();
      cubit = BridgeControlCubit(
        processService: processService,
        statusTracker: statusTracker,
        systemTray: systemTray,
        applicationTerminator: applicationTerminator,
      );
    });

    tearDown(() async {
      await cubit.close();
      await processService.disposeFake();
      statusTracker.dispose();
      await systemTray.disposeFake();
    });

    test("initializes a typed tray menu and reacts to process/status snapshots", () async {
      await cubit.initialize();

      expect(cubit.state.trayAvailability, SystemTrayAvailability.available);
      expect(_textLabels(menu: systemTray.menus.last), containsAll(<String>["Bridge: Off", "Active sessions: 0"]));
      expect(_command(menu: systemTray.menus.last, command: SystemTrayCommand.toggleBridge).label, "Turn Bridge On");

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

    test("Quit terminates only after expected bridge stop completes", () async {
      processService.emit(
        state: const BridgeProcessRunning(pid: 42),
        desiredState: BridgeProcessDesiredState.on,
      );
      processService.stopGate = Completer<void>();
      await cubit.initialize();

      systemTray.emit(command: SystemTrayCommand.quit);
      await pumpEventQueue(times: 2);

      expect(processService.stopCalls, 1);
      expect(applicationTerminator.exitCodes, isEmpty);
      expect(systemTray.disposeCalls, 0);

      processService.stopGate!.complete();
      await pumpEventQueue(times: 2);

      expect(systemTray.disposeCalls, 1);
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

class _FakeDesktopApplicationTerminator() implements DesktopApplicationTerminator {
  final List<int> exitCodes = <int>[];

  @override
  void terminate({required int exitCode}) {
    exitCodes.add(exitCode);
  }
}
