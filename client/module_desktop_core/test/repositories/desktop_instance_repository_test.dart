import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _MockDesktopInstanceApi api;
  late _MockDesktopInstanceStorage storage;
  late DesktopInstanceRepository repository;

  setUp(() {
    api = _MockDesktopInstanceApi();
    storage = _MockDesktopInstanceStorage();
    repository = DesktopInstanceRepository(api: api, storage: storage);
  });

  test("exposes the API activation stream and delegates instance operations", () async {
    const Stream<void> focusRequests = Stream<void>.empty();
    when(() => api.activationRequests).thenAnswer((_) => focusRequests);
    when(() => api.tryAcquirePrimary()).thenAnswer((_) async => true);
    when(() => api.signalPrimary()).thenAnswer((_) async => false);

    expect(repository.focusRequests, same(focusRequests));
    expect(await repository.tryAcquirePrimary(), isTrue);
    expect(await repository.signalPrimary(), isFalse);
  });

  test("delegates desired-state persistence to Layer-1 storage", () async {
    when(() => storage.readBridgeDesiredState()).thenAnswer((_) async => BridgeProcessDesiredState.on);
    when(
      () => storage.writeBridgeDesiredState(state: BridgeProcessDesiredState.off),
    ).thenAnswer((_) async {});

    expect(await repository.readBridgeDesiredState(), BridgeProcessDesiredState.on);
    await repository.writeBridgeDesiredState(state: BridgeProcessDesiredState.off);

    verify(() => storage.writeBridgeDesiredState(state: BridgeProcessDesiredState.off)).called(1);
  });
}

class _MockDesktopInstanceApi() extends Mock implements DesktopInstanceApi;

class _MockDesktopInstanceStorage() extends Mock implements DesktopInstanceStorage;
