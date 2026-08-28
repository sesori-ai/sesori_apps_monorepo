import "dart:async";

import "package:sesori_bridge/src/repositories/models/project_glossary_source.dart";
import "package:sesori_bridge/src/repositories/project_glossary_publication_repository.dart";
import "package:sesori_bridge/src/repositories/project_glossary_repository.dart";
import "package:sesori_bridge/src/repositories/project_repository.dart";
import "package:sesori_bridge/src/services/project_glossary_population_service.dart";
import "package:sesori_bridge/src/services/project_glossary_scope_service.dart";
import "package:sesori_bridge/src/services/project_glossary_term_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  late _FakeProjectRepository projectRepository;
  late _FakeProjectGlossaryScopeService scopeService;
  late _FakeProjectGlossaryRepository glossaryRepository;
  late _FakeProjectGlossaryTermCalculator termCalculator;
  late _FakeProjectGlossaryPublicationRepository publicationRepository;
  late ProjectGlossaryPopulationService service;

  final scope = ProjectGlossaryScope.repository(
    projectKey: ProjectGlossaryKey.parse(
      value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
    ),
  );

  setUp(() {
    projectRepository = _FakeProjectRepository();
    scopeService = _FakeProjectGlossaryScopeService(scope: scope);
    glossaryRepository = _FakeProjectGlossaryRepository();
    termCalculator = _FakeProjectGlossaryTermCalculator();
    publicationRepository = _FakeProjectGlossaryPublicationRepository();
    service = ProjectGlossaryPopulationService(
      projectRepository: projectRepository,
      scopeService: scopeService,
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

    await service.populate(projectId: "project-1");

    expect(projectRepository.requestedProjectIds, ["project-1"]);
    expect(scopeService.projectPaths, ["/workspace/project"]);
    expect(glossaryRepository.projectPaths, ["/workspace/project"]);
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

    await service.populate(projectId: "project-1");

    expect(publicationRepository.additions, isEmpty);
    expect(publicationRepository.removals, hasLength(1));
    expect(publicationRepository.removals.single.scope, scope);
    expect(publicationRepository.removals.single.words, ["LegacyOne", "LegacyTwo"]);
  });

  test("does not scan or publish when no exact scope is available", () async {
    scopeService.scope = null;

    await service.populate(projectId: "project-1");

    expect(glossaryRepository.projectPaths, isEmpty);
    expect(publicationRepository.operations, isEmpty);
  });

  test("coalesces concurrent population requests for the same project", () async {
    final getStarted = Completer<void>();
    final releaseGet = Completer<void>();
    publicationRepository
      ..getStarted = getStarted
      ..releaseGet = releaseGet;

    final first = service.populate(projectId: "project-1");
    await getStarted.future;
    final second = service.populate(projectId: "project-1");

    expect(identical(first, second), isTrue);
    releaseGet.complete();
    await Future.wait([first, second]);

    expect(projectRepository.requestedProjectIds, ["project-1"]);
    expect(publicationRepository.operations, ["get"]);
  });

  test("serializes concurrent population requests", () async {
    final getStarted = Completer<void>();
    final releaseGet = Completer<void>();
    publicationRepository
      ..getStarted = getStarted
      ..releaseGet = releaseGet;
    termCalculator.words = ["CurrentTerm"];
    publicationRepository.existingWords = ["CurrentTerm"];

    final first = service.populate(projectId: "project-1");
    await getStarted.future;
    final second = service.populate(projectId: "project-2");
    await Future<void>.delayed(Duration.zero);

    expect(projectRepository.requestedProjectIds, ["project-1"]);
    releaseGet.complete();
    await Future.wait([first, second]);

    expect(projectRepository.requestedProjectIds, ["project-1", "project-2"]);
    expect(publicationRepository.maximumConcurrentReads, 1);
  });

  test("shutdown aborts transport and rejects later population", () async {
    service.beginShutdown();

    await service.populate(projectId: "project-1");

    expect(publicationRepository.shutdownCount, 1);
    expect(projectRepository.requestedProjectIds, isEmpty);
  });

  test("fails closed before publication when bounded source loading fails", () async {
    final failure = StateError("git failed");
    glossaryRepository.error = failure;

    await expectLater(
      service.populate(projectId: "project-1"),
      throwsA(same(failure)),
    );

    expect(publicationRepository.operations, isEmpty);
  });
}

final class _FakeProjectRepository() implements ProjectRepository {
  final List<String> requestedProjectIds = [];

  @override
  Future<Project> getProject({required String projectId}) async {
    requestedProjectIds.add(projectId);
    return Project(
      id: projectId,
      name: "Project",
      path: "/workspace/project",
      time: null,
      voiceGlossaryKey: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeProjectGlossaryScopeService({required var ProjectGlossaryScope? scope})
    implements ProjectGlossaryScopeService {
  final List<String> projectPaths = [];

  @override
  Future<ProjectGlossaryScope?> resolve({required String projectPath}) async {
    projectPaths.add(projectPath);
    return scope;
  }
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

  @override
  List<String> calculate({required ProjectGlossarySource source}) => List<String>.of(words);
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
