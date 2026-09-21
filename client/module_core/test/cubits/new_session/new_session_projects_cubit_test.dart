import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockProjectListService() extends Mock implements ProjectListService;

void main() {
  test("offers the listed projects, and stays empty when listing fails", () async {
    final service = _MockProjectListService();
    final projects = [testProjectSummary(id: "project-1"), testProjectSummary(id: "project-2")];
    when(service.listProjects).thenAnswer((_) async => ApiResponse.success(Projects(data: projects)));
    final loaded = NewSessionProjectsCubit(projectListService: service);
    await expectLater(loaded.stream, emits(projects));
    await loaded.close();

    when(service.listProjects).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    final failed = NewSessionProjectsCubit(projectListService: service);
    await pumpEventQueue();
    expect(failed.state, isEmpty);
    await failed.close();
  });
}
