import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late MockSecureStorage mockStorage;
  late ClosedProjectsStorage service;
  late Map<String, String?> storageMap;

  setUp(() {
    storageMap = <String, String?>{};
    mockStorage = MockSecureStorage();
    when(() => mockStorage.read(key: any(named: "key"))).thenAnswer((invocation) async {
      final key = invocation.namedArguments[const Symbol('key')] as String;
      return storageMap[key];
    });
    when(
      () => mockStorage.write(
        key: any(named: "key"),
        value: any(named: "value"),
      ),
    ).thenAnswer((invocation) async {
      final key = invocation.namedArguments[const Symbol('key')] as String;
      final value = invocation.namedArguments[const Symbol('value')] as String;
      storageMap[key] = value;
    });
    service = ClosedProjectsStorage(mockStorage);
  });

  group("ClosedProjectsStorage", () {
    test("getClosedProjectIds returns empty set when storage is empty", () async {
      final ids = await service.getClosedProjectIds();

      expect(ids, isEmpty);
    });

    test("closeProject adds ID to the closed set", () async {
      await service.closeProject("project-1");
      final ids = await service.getClosedProjectIds();

      expect(ids, contains("project-1"));
    });

    test("closeProject is idempotent - closing same ID twice doesn't duplicate", () async {
      await service.closeProject("project-1");
      await service.closeProject("project-1");
      final ids = await service.getClosedProjectIds();

      expect(ids, hasLength(1));
      expect(ids, contains("project-1"));
    });

    test("openProject removes ID from the closed set", () async {
      await service.closeProject("project-1");
      await service.closeProject("project-2");
      await service.openProject("project-1");
      final ids = await service.getClosedProjectIds();

      expect(ids, isNot(contains("project-1")));
      expect(ids, contains("project-2"));
    });

    test("openProject on non-closed ID is a no-op and doesn't throw", () async {
      expect(() => service.openProject("non-existent"), returnsNormally);
    });

    test("isProjectClosed returns true for closed project", () async {
      await service.closeProject("project-1");

      final isClosed = await service.isProjectClosed("project-1");

      expect(isClosed, isTrue);
    });

    test("isProjectClosed returns false for open project", () async {
      await service.closeProject("project-1");

      final isClosed = await service.isProjectClosed("project-2");

      expect(isClosed, isFalse);
    });

    test("closeProject writes JSON to SecureStorage with correct key", () async {
      await service.closeProject("project-1");

      verify(
        () => mockStorage.write(
          key: "closed_project_ids",
          value: any(named: "value"),
        ),
      ).called(1);
    });
  });
}
