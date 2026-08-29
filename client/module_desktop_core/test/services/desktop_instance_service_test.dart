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
