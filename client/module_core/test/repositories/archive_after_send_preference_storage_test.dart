import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:test/test.dart";

class _MockPersister() extends Mock implements PersisterRepository;

void main() {
  late _MockPersister persister;
  late ArchiveAfterSendPreferenceStorage storage;

  setUp(() {
    persister = _MockPersister();
    storage = ArchiveAfterSendPreferenceStorage(persister: persister);
  });

  test("reads the stored choice, on when nothing was chosen", () async {
    when(
      () => persister.readBoolOrDefault(key: BoolPreferenceKey.archiveAfterSend, defaultValue: true),
    ).thenAnswer((_) async => false);

    expect(await storage.read(), isFalse);
  });

  test("stays on when storage fails", () async {
    when(
      () => persister.readBoolOrDefault(key: BoolPreferenceKey.archiveAfterSend, defaultValue: true),
    ).thenThrow(Exception("SQL unavailable"));

    expect(await storage.read(), isTrue);
  });

  test("a failed write only loses the choice", () async {
    when(
      () => persister.writeBool(key: BoolPreferenceKey.archiveAfterSend, value: false),
    ).thenThrow(Exception("SQL unavailable"));

    await expectLater(storage.write(value: false), completes);
  });
}
