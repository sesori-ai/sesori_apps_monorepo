import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_bridge/src/repositories/models/project_glossary_source.dart";
import "package:sesori_bridge/src/repositories/project_glossary_publication_repository.dart";
import "package:sesori_bridge/src/repositories/project_glossary_repository.dart";
import "package:sesori_bridge/src/services/project_glossary_population_service.dart";
import "package:sesori_bridge/src/services/project_glossary_term_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  late _FakeProjectGlossaryRepository glossaryRepository;
  late _FakeProjectGlossaryTermCalculator termCalculator;
  late _FakeProjectGlossaryPublicationRepository publicationRepository;
  late ProjectGlossaryPopulationService service;

  final scope = ProjectGlossaryScope.repository(
    projectKey: ProjectGlossaryKey.parse(
      value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    ),
  );
  final otherScope = ProjectGlossaryScope.repository(
    projectKey: ProjectGlossaryKey.parse(
      value: "prj_v1_gBrBSzNu-bDcQWAcJVHWREq3Mlkj9J6GQoxl2Mlt7LY",
    ),
  );
  final startTime = DateTime.utc(2026, 10, 31, 12);

  Future<void> refreshAt({required Duration elapsed, String projectPath = "/workspace/project"}) => withClock(
    Clock.fixed(startTime.add(elapsed)),
    () => service.refreshIfDue(scope: scope, projectPath: projectPath),
  );

  setUp(() {
    glossaryRepository = _FakeProjectGlossaryRepository();
    termCalculator = _FakeProjectGlossaryTermCalculator();
    publicationRepository = _FakeProjectGlossaryPublicationRepository();
    service = ProjectGlossaryPopulationService(
      glossaryRepository: glossaryRepository,
      termCalculator: termCalculator,
      publicationRepository: publicationRepository,
    );
    addTearDown(service.dispose);
  });

  test("adds exact ownership before removing stale words in bounded mutations", () async {
    termCalculator.words = ["CurrentTerm", "SharedTerm"];
    publicationRepository.existingWords = [
      "SharedTerm",
      for (var index = 0; index < 203; index++) "LegacyTerm$index",
    ];

    await service.refreshIfDue(scope: scope, projectPath: "/workspace/project");

    expect(glossaryRepository.projectPaths, ["/workspace/project"]);
    // The whole glossary must fit the single add request.
    expect(termCalculator.requestedMaximumTerms, [100]);
    expect(publicationRepository.operations, ["get", "add", "remove", "remove", "remove"]);
    expect(publicationRepository.additions, hasLength(1));
    expect(publicationRepository.additions.single.scope, scope);
    expect(publicationRepository.additions.single.words, ["CurrentTerm", "SharedTerm"]);
    expect(publicationRepository.removals.map((mutation) => mutation.scope), everyElement(scope));
    expect(publicationRepository.removals.map((mutation) => mutation.words.length), [100, 100, 3]);
    expect(
      publicationRepository.removals.expand((mutation) => mutation.words),
      [for (var index = 0; index < 203; index++) "LegacyTerm$index"],
    );
  });

  test("removes this scope's stale ownership when inference yields no terms", () async {
    publicationRepository.existingWords = ["LegacyOne", "LegacyTwo"];

    await service.refreshIfDue(scope: scope, projectPath: "/workspace/project");

    expect(publicationRepository.additions, isEmpty);
    expect(publicationRepository.removals, hasLength(1));
    expect(publicationRepository.removals.single.scope, scope);
    expect(publicationRepository.removals.single.words, ["LegacyOne", "LegacyTwo"]);
  });

  test("refreshes a glossary once a day", () async {
    await refreshAt(elapsed: Duration.zero);
    await refreshAt(elapsed: const Duration(hours: 23, minutes: 59));
    expect(glossaryRepository.projectPaths, hasLength(1));

    await refreshAt(elapsed: const Duration(hours: 24));
    expect(glossaryRepository.projectPaths, hasLength(2));
  });

  test("worktrees that share a glossary share its refresh", () async {
    await refreshAt(elapsed: Duration.zero, projectPath: "/workspace/project");
    await refreshAt(elapsed: const Duration(minutes: 1), projectPath: "/workspace/project-worktree");

    expect(glossaryRepository.projectPaths, ["/workspace/project"]);
  });

  test("a failed refresh retries after ten minutes, not on the next request", () async {
    glossaryRepository.error = StateError("git failed");

    await refreshAt(elapsed: Duration.zero);
    await refreshAt(elapsed: const Duration(minutes: 9));
    expect(glossaryRepository.projectPaths, hasLength(1));
    expect(publicationRepository.operations, isEmpty);

    glossaryRepository.error = null;
    await refreshAt(elapsed: const Duration(minutes: 10));
    expect(glossaryRepository.projectPaths, hasLength(2));
    expect(publicationRepository.operations, ["get"]);
  });

  test("a request during a running refresh starts no second one", () async {
    final getStarted = Completer<void>();
    final releaseGet = Completer<void>();
    publicationRepository
      ..getStarted = getStarted
      ..releaseGet = releaseGet;

    final first = service.refreshIfDue(scope: scope, projectPath: "/workspace/project");
    await getStarted.future;
    await service.refreshIfDue(scope: scope, projectPath: "/workspace/project");
    releaseGet.complete();
    await first;

    expect(publicationRepository.operations, ["get"]);
  });

  test("refreshes different glossaries one at a time", () async {
    final getStarted = Completer<void>();
    final releaseGet = Completer<void>();
    publicationRepository
      ..getStarted = getStarted
      ..releaseGet = releaseGet;

    final first = service.refreshIfDue(scope: scope, projectPath: "/workspace/project");
    await getStarted.future;
    final second = service.refreshIfDue(scope: otherScope, projectPath: "/workspace/other");
    await Future<void>.delayed(Duration.zero);

    expect(glossaryRepository.projectPaths, ["/workspace/project"]);
    releaseGet.complete();
    await Future.wait([first, second]);

    expect(glossaryRepository.projectPaths, ["/workspace/project", "/workspace/other"]);
    expect(publicationRepository.maximumConcurrentReads, 1);
  });

  test("shutdown aborts transport, skips queued work and rejects later refreshes", () async {
    final getStarted = Completer<void>();
    final releaseGet = Completer<void>();
    publicationRepository
      ..getStarted = getStarted
      ..releaseGet = releaseGet;

    final running = service.refreshIfDue(scope: scope, projectPath: "/workspace/project");
    await getStarted.future;
    final queued = service.refreshIfDue(scope: otherScope, projectPath: "/workspace/other");
    service.beginShutdown();
    await service.refreshIfDue(
      scope: ProjectGlossaryScope.repository(
        projectKey: ProjectGlossaryKey.parse(
          value: "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        ),
      ),
      projectPath: "/workspace/late",
    );
    releaseGet.complete();
    await Future.wait([running, queued]);

    expect(publicationRepository.shutdownCount, 1);
    expect(glossaryRepository.projectPaths, ["/workspace/project"]);
    expect(publicationRepository.operations, ["get"]);
  });
}

final class _FakeProjectGlossaryRepository() implements ProjectGlossaryRepository {
  final List<String> projectPaths = [];
  Object? error;

  @override
  Future<ProjectGlossarySource> loadSource({required String projectPath}) async {
    projectPaths.add(projectPath);
    if (error case final error?) throw error;
    return ProjectGlossarySource(
      projectName: "Project",
      repositoryName: null,
      trackedPaths: const [],
      metadataDocuments: const [],
    );
  }
}

final class _FakeProjectGlossaryTermCalculator() implements ProjectGlossaryTermCalculator {
  List<String> words = [];
  final List<int> requestedMaximumTerms = [];

  @override
  List<String> calculate({required ProjectGlossarySource source, required int maximumTerms}) {
    requestedMaximumTerms.add(maximumTerms);
    return List<String>.of(words);
  }
}

final class _FakeProjectGlossaryPublicationRepository() implements ProjectGlossaryPublicationRepository {
  List<String> existingWords = [];
  final List<String> operations = [];
  final List<({ProjectGlossaryScope scope, List<String> words})> additions = [];
  final List<({ProjectGlossaryScope scope, List<String> words})> removals = [];
  Completer<void>? getStarted;
  Completer<void>? releaseGet;
  int activeReads = 0;
  int maximumConcurrentReads = 0;
  int shutdownCount = 0;

  @override
  void beginShutdown() {
    shutdownCount++;
  }

  @override
  Future<List<String>> getWords({required ProjectGlossaryKey projectKey}) async {
    operations.add("get");
    activeReads++;
    maximumConcurrentReads = activeReads > maximumConcurrentReads ? activeReads : maximumConcurrentReads;
    final started = getStarted;
    if (started != null && !started.isCompleted) started.complete();
    await releaseGet?.future;
    activeReads--;
    return List<String>.of(existingWords);
  }

  @override
  Future<List<String>> addWords({required ProjectGlossaryScope scope, required List<String> words}) async {
    operations.add("add");
    additions.add((scope: scope, words: List<String>.of(words)));
    return List<String>.of(words);
  }

  @override
  Future<int> removeWords({required ProjectGlossaryScope scope, required List<String> words}) async {
    operations.add("remove");
    removals.add((scope: scope, words: List<String>.of(words)));
    return words.length;
  }
}
