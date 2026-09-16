import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  setUpAll(() {
    registerFallbackValue(BridgeProcessDesiredState.off);
  });

  late _MockDesktopInstanceRepository repository;
  late DesktopInstanceService service;

  setUp(() {
    repository = _MockDesktopInstanceRepository();
    service = DesktopInstanceService(repository: repository);
  });

  test("a successful lock claim owns the primary launch", () async {
    when(() => repository.tryAcquirePrimary()).thenAnswer((_) async => true);

    expect(await service.claimLaunch(), DesktopInstanceLaunchDisposition.primary);
    verifyNever(() => repository.signalPrimary());
  });

  test("a live owner is activated and the second launch stays secondary", () async {
    when(() => repository.tryAcquirePrimary()).thenAnswer((_) async => false);
    when(() => repository.signalPrimary()).thenAnswer((_) async => true);

    expect(await service.claimLaunch(), DesktopInstanceLaunchDisposition.secondaryActivated);
  });

  test("reclaims the lock when the owner exits during activation", () async {
    int claims = 0;
    when(() => repository.tryAcquirePrimary()).thenAnswer((_) async => ++claims == 2);
    when(() => repository.signalPrimary()).thenAnswer((_) async => false);

    expect(await service.claimLaunch(), DesktopInstanceLaunchDisposition.primary);
    expect(claims, 2);
  });

  test("never starts a duplicate when a live lock has a broken activation channel", () async {
    when(() => repository.tryAcquirePrimary()).thenAnswer((_) async => false);
    when(() => repository.signalPrimary()).thenAnswer((_) async => false);

    expect(await service.claimLaunch(), DesktopInstanceLaunchDisposition.secondaryActivationFailed);
    verify(() => repository.tryAcquirePrimary()).called(2);
  });

  test("a newer persisted intent cancels an in-flight startup restore read", () async {
    final Completer<BridgeProcessDesiredState> stateRead = Completer<BridgeProcessDesiredState>();
    when(() => repository.readBridgeDesiredState()).thenAnswer((_) => stateRead.future);
    when(
      () => repository.writeBridgeDesiredState(state: BridgeProcessDesiredState.off),
    ).thenAnswer((_) async {});

    final Future<BridgeProcessDesiredState?> restore = service.readBridgeDesiredStateForRestore();
    final Future<void> persistOff = service.writeBridgeDesiredState(state: BridgeProcessDesiredState.off);
    stateRead.complete(BridgeProcessDesiredState.on);

    expect(await restore, isNull);
    await persistOff;
  });

  test("missing intent restores as Off without persisting it", () async {
    when(repository.readBridgeDesiredState).thenAnswer((_) async => null);
    expect(await service.readBridgeDesiredStateForRestore(), BridgeProcessDesiredState.off);
    verifyNever(() => repository.writeBridgeDesiredState(state: any(named: "state")));
  });

  test("concurrent first-run checks write On only once", () async {
    BridgeProcessDesiredState? persisted;
    when(repository.readBridgeDesiredState).thenAnswer((_) async => persisted);
    when(() => repository.writeBridgeDesiredState(state: any(named: "state"))).thenAnswer((invocation) async {
      persisted = invocation.namedArguments[#state]! as BridgeProcessDesiredState;
    });
    expect(await Future.wait([service.initializeFirstRunBridgeState(), service.initializeFirstRunBridgeState()]), [
      true,
      false,
    ]);
    verify(() => repository.writeBridgeDesiredState(state: BridgeProcessDesiredState.on)).called(1);
  });

  for (final saved in BridgeProcessDesiredState.values) {
    test("first-run defaults leave saved $saved untouched", () async {
      when(repository.readBridgeDesiredState).thenAnswer((_) async => saved);
      expect(await service.initializeFirstRunBridgeState(), isFalse);
      verifyNever(() => repository.writeBridgeDesiredState(state: any(named: "state")));
    });
  }

  test("Off during a slow first-run read prevents the default", () async {
    final read = Completer<BridgeProcessDesiredState?>();
    when(repository.readBridgeDesiredState).thenAnswer((_) => read.future);
    when(() => repository.writeBridgeDesiredState(state: BridgeProcessDesiredState.off)).thenAnswer((_) async {});
    final initialize = service.initializeFirstRunBridgeState();
    final off = service.writeBridgeDesiredState(state: BridgeProcessDesiredState.off);
    read.complete(null);
    expect(await initialize, isFalse);
    await off;
    verifyNever(() => repository.writeBridgeDesiredState(state: BridgeProcessDesiredState.on));
  });

  test("Off during the first-run write wins persistence and cancels start admission", () async {
    final write = Completer<void>();
    final writes = <BridgeProcessDesiredState>[];
    when(repository.readBridgeDesiredState).thenAnswer((_) async => null);
    when(() => repository.writeBridgeDesiredState(state: any(named: "state"))).thenAnswer((invocation) async {
      final state = invocation.namedArguments[#state]! as BridgeProcessDesiredState;
      writes.add(state);
      if (state == BridgeProcessDesiredState.on) await write.future;
    });
    final initialize = service.initializeFirstRunBridgeState();
    await Future<void>.delayed(Duration.zero);
    final off = service.writeBridgeDesiredState(state: BridgeProcessDesiredState.off);
    write.complete();
    expect(await initialize, isFalse);
    await off;
    expect(writes, [BridgeProcessDesiredState.on, BridgeProcessDesiredState.off]);
  });

  test("failed first-run persistence does not strand later explicit intent", () async {
    when(repository.readBridgeDesiredState).thenAnswer((_) async => null);
    when(() => repository.writeBridgeDesiredState(state: BridgeProcessDesiredState.on)).thenThrow(StateError("disk"));
    when(() => repository.writeBridgeDesiredState(state: BridgeProcessDesiredState.off)).thenAnswer((_) async {});
    await expectLater(service.initializeFirstRunBridgeState(), throwsStateError);
    await service.writeBridgeDesiredState(state: BridgeProcessDesiredState.off);
  });

  test("serializes desired-state writes in request order", () async {
    final Completer<void> onWrite = Completer<void>();
    final List<BridgeProcessDesiredState> writes = <BridgeProcessDesiredState>[];
    when(() => repository.writeBridgeDesiredState(state: any(named: "state"))).thenAnswer((invocation) {
      final BridgeProcessDesiredState state = invocation.namedArguments[#state]! as BridgeProcessDesiredState;
      writes.add(state);
      return state == BridgeProcessDesiredState.on ? onWrite.future : Future<void>.value();
    });

    final Future<void> persistOn = service.writeBridgeDesiredState(state: BridgeProcessDesiredState.on);
    final Future<void> persistOff = service.writeBridgeDesiredState(state: BridgeProcessDesiredState.off);
    await Future<void>.delayed(Duration.zero);

    expect(writes, <BridgeProcessDesiredState>[BridgeProcessDesiredState.on]);

    onWrite.complete();
    await Future.wait(<Future<void>>[persistOn, persistOff]);
    expect(writes, <BridgeProcessDesiredState>[
      BridgeProcessDesiredState.on,
      BridgeProcessDesiredState.off,
    ]);
  });
}

class _MockDesktopInstanceRepository() extends Mock implements DesktopInstanceRepository;
