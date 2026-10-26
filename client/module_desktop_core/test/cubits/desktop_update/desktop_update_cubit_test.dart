import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  setUpAll(() {
    registerFallbackValue(DesktopAutomaticUpdates.enabled);
  });

  late BehaviorSubject<DesktopUpdateState> states;
  late BehaviorSubject<DesktopAutomaticUpdates> automaticUpdates;
  late _MockDesktopUpdateService service;
  late DesktopUpdateCubit cubit;

  setUp(() {
    states = BehaviorSubject<DesktopUpdateState>.seeded(const DesktopUpdateManagedBySystem());
    automaticUpdates = BehaviorSubject<DesktopAutomaticUpdates>.seeded(DesktopAutomaticUpdates.enabled);
    service = _MockDesktopUpdateService();
    when(() => service.states).thenAnswer((_) => states.stream);
    when(() => service.currentState).thenAnswer((_) => states.value);
    when(() => service.automaticUpdates).thenAnswer((_) => automaticUpdates.stream);
    when(() => service.currentAutomaticUpdates).thenAnswer((_) => automaticUpdates.value);
    cubit = DesktopUpdateCubit(service: service);
  });

  tearDown(() async {
    await cubit.close();
    await states.close();
    await automaticUpdates.close();
  });

  test("starts from the service and follows its update and toggle states", () async {
    expect(cubit.state.update, isA<DesktopUpdateManagedBySystem>());
    expect(cubit.state.automaticUpdates, DesktopAutomaticUpdates.enabled);

    states.add(const DesktopUpdateReady(version: "1.8.5"));
    automaticUpdates.add(DesktopAutomaticUpdates.disabled);
    await pumpEventQueue();

    expect(cubit.state.update, isA<DesktopUpdateReady>());
    expect(cubit.state.automaticUpdates, DesktopAutomaticUpdates.disabled);
  });

  test("the toggle writes through the service and a failed write is only logged", () async {
    when(
      () => service.setAutomaticUpdates(preference: any(named: "preference")),
    ).thenThrow(const FileSystemFailure());

    await cubit.setAutomaticUpdates(enabled: false);

    verify(() => service.setAutomaticUpdates(preference: DesktopAutomaticUpdates.disabled)).called(1);
  });

  test("Check for updates runs the service's single check", () {
    when(() => service.check()).thenAnswer((_) async {});
    cubit.checkForUpdates();
    verify(() => service.check()).called(1);
  });
}

class const FileSystemFailure() implements Exception;

class _MockDesktopUpdateService() extends Mock implements DesktopUpdateService;
