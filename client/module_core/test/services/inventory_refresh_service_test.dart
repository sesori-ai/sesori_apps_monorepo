import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  late InventoryRefreshService service;

  setUp(() => service = InventoryRefreshService());
  tearDown(() => service.dispose());

  test("project refresh reports failure without an inventory owner", () async {
    expect(
      await service.refreshProjectInventory(),
      isA<ProjectInventoryRefreshResult>()
          .having((result) => result.succeeded, "succeeded", isFalse)
          .having((result) => result.projectIds, "projectIds", isEmpty),
    );
  });

  test("project owner completes the request", () async {
    final subscription = service.projectRequests.listen(
      (request) => request.complete(
        result: const ProjectInventoryRefreshResult(succeeded: true, projectIds: ["project-1"]),
      ),
    );
    addTearDown(subscription.cancel);

    final result = await service.refreshProjectInventory();

    expect(result.succeeded, isTrue);
    expect(result.projectIds, ["project-1"]);
  });

  test("session request deduplicates projects and an empty batch succeeds", () async {
    final subscription = service.sessionRequests.listen((request) {
      expect(request.projectIds, ["project-1", "project-2"]);
      request.complete(succeeded: true);
    });
    addTearDown(subscription.cancel);

    expect(
      await service.refreshSessionInventories(
        projectIds: const ["project-1", "project-2", "project-1"],
      ),
      isTrue,
    );
    expect(await service.refreshSessionInventories(projectIds: const []), isTrue);
  });
}
