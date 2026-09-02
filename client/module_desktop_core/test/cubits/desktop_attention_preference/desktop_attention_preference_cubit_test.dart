import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _MockDesktopAttentionService service;
  late BehaviorSubject<DesktopAttentionPreference> preferences;
  late DesktopAttentionPreferenceCubit cubit;

  setUp(() {
    service = _MockDesktopAttentionService();
    preferences = BehaviorSubject<DesktopAttentionPreference>.seeded(DesktopAttentionPreference.enabled);
    when(() => service.currentPreference).thenReturn(DesktopAttentionPreference.enabled);
    when(() => service.preference).thenAnswer((_) => preferences.stream);
    cubit = DesktopAttentionPreferenceCubit(service: service);
  });

  tearDown(() async {
    await cubit.close();
    await preferences.close();
  });

  test("mirrors service preference changes", () async {
    preferences.add(DesktopAttentionPreference.disabled);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, DesktopAttentionPreference.disabled);
  });

  test("writes the requested enabled state through the service", () async {
    when(
      () => service.setPreference(preference: DesktopAttentionPreference.disabled),
    ).thenAnswer((_) async {});

    await cubit.setEnabled(enabled: false);

    verify(
      () => service.setPreference(preference: DesktopAttentionPreference.disabled),
    ).called(1);
  });

  test("keeps its state when persistence fails", () async {
    when(
      () => service.setPreference(preference: DesktopAttentionPreference.disabled),
    ).thenThrow(StateError("disk unavailable"));

    await cubit.setEnabled(enabled: false);

    expect(cubit.state, DesktopAttentionPreference.enabled);
  });
}

class _MockDesktopAttentionService() extends Mock implements DesktopAttentionService;
