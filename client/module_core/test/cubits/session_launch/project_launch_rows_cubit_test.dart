import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  final existing = testSession(id: "existing");
  final created = testSession(id: "created");
  late BehaviorSubject<Map<String, RecentSessionsEntry>> inventory;
  late SessionLaunchRepository launches;
  // The slots' inputs here: sessions the surface leaves out of its slot.
  late ProjectLaunchRowsCubit<Set<String>> cubit;

  Map<String, RecentSessionsEntry> loaded(List<Session> sessions) => {
    "project-1": RecentSessionsLoaded(
      sourceSessions: sessions,
      visibleSessions: sessions,
      activityBySessionId: const {},
      listStateBySessionId: const {},
    ),
  };

  setUp(() {
    inventory = BehaviorSubject.seeded(loaded([existing]));
    final inventoryService = _MockInventoryService();
    when(() => inventoryService.state).thenAnswer((_) => inventory.stream);
    launches = inMemorySessionLaunchRepository();
    cubit = ProjectLaunchRowsCubit(
      inventoryService: inventoryService,
      launchService: inMemorySessionLaunchService(launchRepository: launches),
      slots: ({required entries, required inputs}) => {
        for (final MapEntry(key: projectId, value: entry) in entries.entries)
          if (entry is RecentSessionsLoaded)
            projectId: (
              sessions: [
                for (final session in entry.visibleSessions)
                  if (!inputs.contains(session.id)) session,
              ],
              placedSessionIds: const {},
            ),
      },
      slotInputs: const {},
      initialRows: const {},
    );
  });
  tearDown(() async {
    await cubit.close();
    await inventory.close();
  });

  void launch() => launches.start(
    launchId: "launch-1",
    projectId: "project-1",
    pluginId: "claude",
    startedAt: DateTime.utc(2026, 10, 7, 12),
    projectName: "Sesori",
    submission: NewSessionSubmissionSnapshot.text(
      draft: ComposerDraft.typed(text: "Fix the bug"),
      attachments: const [],
    ),
  );

  test("carries a launch's row across updates until its session takes the row's place", () async {
    launch();
    await pumpEventQueue();
    final rows = cubit.state["project-1"]?.placeholders ?? const <LaunchingSession>[];
    expect([for (final row in rows) row.launchId], ["launch-1"]);

    launches.promote(launchId: "launch-1", session: created);
    await pumpEventQueue();
    expect(cubit.state["project-1"]?.heldSessionIds, {"created"}, reason: "its session has not arrived yet");

    inventory.add(loaded([created, existing]));
    await pumpEventQueue();
    expect(cubit.state["project-1"]?.placeholders, isEmpty);
    expect(cubit.state["project-1"]?.rowKeys, {"created": "launch-1"});
  });

  test("re-resolves when only the slots' inputs change", () async {
    cubit.updateSlotInputs(inputs: {"created"});
    launch();
    launches.promote(launchId: "launch-1", session: created);
    inventory.add(loaded([created, existing]));
    await pumpEventQueue();
    expect(cubit.state["project-1"]?.heldSessionIds, {"created"}, reason: "it is outside the slot");

    cubit.updateSlotInputs(inputs: const {});
    expect(cubit.state["project-1"]?.placeholders, isEmpty);
    expect(cubit.state["project-1"]?.rowKeys, {"created": "launch-1"});
  });
}

class _MockInventoryService() extends Mock implements RecentSessionInventoryService;
