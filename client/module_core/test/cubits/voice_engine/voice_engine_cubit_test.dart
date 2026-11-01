import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockVoiceModeRepository() extends Mock implements VoiceModeRepository;

void main() {
  late _MockVoiceModeRepository repository;

  setUpAll(() => registerFallbackValue(VoiceEngine.device));

  setUp(() {
    repository = _MockVoiceModeRepository();
    when(() => repository.engine).thenReturn(VoiceEngine.embedded);
    when(() => repository.setEngine(engine: any(named: "engine"))).thenAnswer((_) async {});
  });

  test("shows no engine until the stored pick has been read", () async {
    final load = Completer<void>();
    when(repository.loadEngine).thenAnswer((_) => load.future);
    final cubit = VoiceEngineCubit(voiceModeRepository: repository);
    addTearDown(cubit.close);

    expect(cubit.state, isNull);

    load.complete();
    await pumpEventQueue();

    expect(cubit.state, VoiceEngine.embedded);
  });

  test("a pick shows at once and goes to the repository", () async {
    when(repository.loadEngine).thenAnswer((_) async {});
    final cubit = VoiceEngineCubit(voiceModeRepository: repository);
    addTearDown(cubit.close);
    await pumpEventQueue();

    unawaited(cubit.select(engine: VoiceEngine.remote));

    expect(cubit.state, VoiceEngine.remote);
    verify(() => repository.setEngine(engine: VoiceEngine.remote)).called(1);
  });

  test("a pick before the read finishes isn't replaced by it", () async {
    final load = Completer<void>();
    when(repository.loadEngine).thenAnswer((_) => load.future);
    final cubit = VoiceEngineCubit(voiceModeRepository: repository);
    addTearDown(cubit.close);

    unawaited(cubit.select(engine: VoiceEngine.remote));
    load.complete();
    await pumpEventQueue();

    expect(cubit.state, VoiceEngine.remote);
  });
}
