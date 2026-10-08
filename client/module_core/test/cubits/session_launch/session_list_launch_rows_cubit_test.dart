import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  final existing = testSession(id: "existing");
  final created = testSession(id: "created");
  late SessionLaunchRepository launches;
  late SessionListLaunchRowsCubit cubit;

  setUp(() {
    launches = inMemorySessionLaunchRepository();
    cubit = SessionListLaunchRowsCubit(
      launchService: inMemorySessionLaunchService(launchRepository: launches),
      projectId: "project-1",
      activeSessions: null,
    );
  });
  tearDown(() => cubit.close());

  void launch({required String launchId, required String projectId}) => launches.start(
    launchId: launchId,
    projectId: projectId,
    pluginId: "claude",
    startedAt: DateTime.utc(2026, 10, 7, 12),
    projectName: "Sesori",
    submission: NewSessionSubmissionSnapshot.text(
      draft: ComposerDraft.typed(text: "Fix the bug"),
      attachments: const [],
    ),
  );

  test("keeps its project's launch row while the list loads, until the session takes its place", () async {
    launch(launchId: "launch-1", projectId: "project-1");
    launch(launchId: "launch-2", projectId: "project-2");
    await pumpEventQueue();
    expect([for (final row in cubit.state.placeholders) row.launchId], ["launch-1"]);

    launches.promote(launchId: "launch-1", session: created);
    await pumpEventQueue();
    expect([for (final row in cubit.state.placeholders) row.launchId], ["launch-1"], reason: "the list is loading");

    cubit.updateList(activeSessions: [created, existing]);
    expect(cubit.state.placeholders, isEmpty);
    expect(cubit.state.rowKeys, {"created": "launch-1"});
  });
}
