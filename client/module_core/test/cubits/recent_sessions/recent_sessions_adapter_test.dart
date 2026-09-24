import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  late _MockInventoryService inventory;
  late BehaviorSubject<Map<String, RecentSessionsEntry>> snapshots;

  setUp(() {
    inventory = _MockInventoryService();
    snapshots = BehaviorSubject.seeded(const {});
    when(() => inventory.state).thenAnswer((_) => snapshots.stream);
  });
  tearDown(() => snapshots.close());

  test("seeds the current inventory and mirrors subsequent values without copying", () async {
    final initial = Map<String, RecentSessionsEntry>.unmodifiable({"one": RecentSessionsLoading()});
    snapshots.add(initial);
    final cubit = RecentSessionsCubit(inventoryService: inventory);
    addTearDown(cubit.close);
    expect(cubit.state, same(initial));

    final observed = cubit.stream.take(2).toList();
    final failed = Map<String, RecentSessionsEntry>.unmodifiable({
      "one": const RecentSessionsFailed(reason: RemoteFailureReason.unknown),
    });
    // Exercise an update before the subject's initial replay is delivered.
    snapshots.add(failed);
    snapshots.add(const {});
    expect(await observed, [same(failed), isEmpty]);
  });

  test("delegates the explicit project retry to the inventory", () async {
    when(() => inventory.retry(projectId: "one")).thenAnswer((_) async {});
    final cubit = RecentSessionsCubit(inventoryService: inventory);
    addTearDown(cubit.close);
    await cubit.retry(projectId: "one");
    verify(() => inventory.retry(projectId: "one")).called(1);
  });

  test("closing a consumer leaves the service live for a replacement consumer", () async {
    final cubit = RecentSessionsCubit(inventoryService: inventory);
    await cubit.close();
    expect(snapshots.hasListener, isFalse);
    expect(snapshots.isClosed, isFalse);
    verifyNever(inventory.dispose);

    final retained = Map<String, RecentSessionsEntry>.unmodifiable({"one": RecentSessionsLoading()});
    snapshots.add(retained);
    final replacement = RecentSessionsCubit(inventoryService: inventory);
    addTearDown(replacement.close);
    expect(replacement.state, same(retained));
    final next = replacement.stream.first;
    snapshots.add(const {});
    expect(await next, isEmpty);
  });
}

class _MockInventoryService() extends Mock implements RecentSessionInventoryService;
