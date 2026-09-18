import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _InventoryRefreshService inventories;
  late DesktopSidebarRefreshService service;

  setUp(() {
    inventories = _InventoryRefreshService();
    when(inventories.refreshProjectInventory).thenAnswer(
      (_) async => const ProjectInventoryRefreshResult(succeeded: true, projectIds: ["old"]),
    );
    when(
      () => inventories.refreshSessionInventories(projectIds: any(named: "projectIds")),
    ).thenAnswer((_) async => true);
    service = DesktopSidebarRefreshService(inventoryRefreshService: inventories);
  });

  test("refreshes resulting session inventories after the project snapshot", () async {
    final projectReply = Completer<ProjectInventoryRefreshResult>();
    when(inventories.refreshProjectInventory).thenAnswer((_) => projectReply.future);
    final pending = service.refresh();
    verifyNever(() => inventories.refreshSessionInventories(projectIds: any(named: "projectIds")));
    projectReply.complete(
      const ProjectInventoryRefreshResult(succeeded: true, projectIds: ["new", "other"]),
    );

    final result = await pending;

    final captured = verify(
      () => inventories.refreshSessionInventories(projectIds: captureAny(named: "projectIds")),
    ).captured.single;
    expect(captured, orderedEquals(["new", "other"]));
    expect(result, DesktopSidebarRefreshResult.succeeded);
  });

  test("refreshes retained sessions but reports project failure", () async {
    when(inventories.refreshProjectInventory).thenAnswer(
      (_) async => const ProjectInventoryRefreshResult(succeeded: false, projectIds: ["retained"]),
    );

    final result = await service.refresh();

    verify(() => inventories.refreshSessionInventories(projectIds: ["retained"])).called(1);
    expect(result, DesktopSidebarRefreshResult.failed);
  });

  test("reports session inventory failure", () async {
    when(
      () => inventories.refreshSessionInventories(projectIds: any(named: "projectIds")),
    ).thenAnswer((_) async => false);

    expect(await service.refresh(), DesktopSidebarRefreshResult.failed);
  });

  test("logs and reports an unexpected workflow failure", () async {
    when(inventories.refreshProjectInventory).thenThrow(StateError("unexpected"));

    expect(await service.refresh(), DesktopSidebarRefreshResult.failed);
    verifyNever(() => inventories.refreshSessionInventories(projectIds: any(named: "projectIds")));
  });
}

class _InventoryRefreshService() extends Mock implements InventoryRefreshService;
