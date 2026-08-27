import "dart:async";

import "package:sesori_bridge/src/auth/project_glossary_key_material_provider.dart";
import "package:sesori_bridge/src/foundation/abortable_request.dart";
import "package:sesori_bridge/src/repositories/models/project_glossary_source.dart";
import "package:sesori_bridge/src/repositories/project_glossary_repository.dart";
import "package:sesori_bridge/src/repositories/project_repository.dart";
import "package:sesori_bridge/src/services/project_glossary_service.dart";
import "package:sesori_bridge/src/services/project_glossary_term_calculator.dart";
import "package:sesori_shared/sesori_shared.dart" show deriveProjectGlossaryKey;
import "package:test/test.dart";

void main() {
  const bridgeId = "br_test1234";
  const projectSecret = <int>[
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
  ];
  const keyMaterialProvider = _TestKeyMaterialProvider(bridgeId, projectSecret);

  test("serializes projects and coalesces duplicate scheduling", () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final glossaryRepository = _FakeProjectGlossaryRepository(
      existingWords: const {},
      source: null,
      getWordsCallback: ({required String projectKey}) async {
        if (!firstStarted.isCompleted) {
          firstStarted.complete();
          await releaseFirst.future;
        }
        return [];
      },
    );
    final service = ProjectGlossaryService(
      keyMaterialProvider: keyMaterialProvider,
      projectRepository: _FakeProjectRepository(
        paths: {"project-a": "/projects/a", "project-b": "/projects/b"},
      ),
      glossaryRepository: glossaryRepository,
      termCalculator: const ProjectGlossaryTermCalculator(),
    );

    service.schedule(projectId: "project-a");
    await firstStarted.future;
    service.schedule(projectId: "project-a");
    service.schedule(projectId: "project-b");
    await Future<void>.delayed(Duration.zero);

    expect(glossaryRepository.getWordsProjectKeys, hasLength(1));
    releaseFirst.complete();
    await service.drain();

    expect(glossaryRepository.getWordsProjectKeys, [
      deriveProjectGlossaryKey(secret: projectSecret, bridgeId: bridgeId, projectId: "project-a"),
      deriveProjectGlossaryKey(secret: projectSecret, bridgeId: bridgeId, projectId: "project-b"),
    ]);
  });

  test("shutdown aborts admitted work and rejects new scheduling before drain", () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final glossaryRepository = _FakeProjectGlossaryRepository(
      existingWords: const {},
      source: null,
      getWordsCallback: ({required String projectKey}) async {
        firstStarted.complete();
        await releaseFirst.future;
        return [];
      },
    );
    final service = ProjectGlossaryService(
      keyMaterialProvider: keyMaterialProvider,
      projectRepository: _FakeProjectRepository(
        paths: {"project-a": "/projects/a", "project-b": "/projects/b"},
      ),
      glossaryRepository: glossaryRepository,
      termCalculator: const ProjectGlossaryTermCalculator(),
    );

    service.schedule(projectId: "project-a");
    await firstStarted.future;
    service.beginShutdown();
    service.schedule(projectId: "project-b");
    releaseFirst.complete();
    await service.drain();

    expect(glossaryRepository.getWordsProjectKeys, [
      deriveProjectGlossaryKey(secret: projectSecret, bridgeId: bridgeId, projectId: "project-a"),
    ]);
    expect(glossaryRepository.abortSignals.single.isAborted, isTrue);
  });

  test("fills only the remaining capacity and ignores existing case variants", () async {
    const projectId = "/Users/developer/AcmeCompiler";
    final projectKey = deriveProjectGlossaryKey(secret: projectSecret, bridgeId: bridgeId, projectId: projectId);
    final existingWords = [
      "AcmeCompiler",
      for (var index = 0; index < 47; index++) "Existing$index",
    ];
    final glossaryRepository = _FakeProjectGlossaryRepository(
      existingWords: {projectKey: existingWords},
      source: ProjectGlossarySource(
        projectName: "AcmeCompiler",
        repositoryName: "acme_compiler",
        trackedPaths: const [
          "lib/AcmeCompiler.dart",
          "lib/QuasarEngine.dart",
          "lib/XChaCha20Cipher.dart",
        ],
        metadataDocuments: const [],
      ),
      getWordsCallback: null,
    );
    final service = ProjectGlossaryService(
      keyMaterialProvider: keyMaterialProvider,
      projectRepository: _FakeProjectRepository(paths: {projectId: "/moved/AcmeCompiler"}),
      glossaryRepository: glossaryRepository,
      termCalculator: const ProjectGlossaryTermCalculator(),
    );

    service.schedule(projectId: projectId);
    await service.drain();

    expect(glossaryRepository.addedProjectKey, projectKey);
    expect(glossaryRepository.addedWords, hasLength(2));
    expect(glossaryRepository.addedWords, isNot(contains("AcmeCompiler")));
  });

  test("skips local source scanning when the server already has fifty terms", () async {
    const projectId = "project-full";
    final projectKey = deriveProjectGlossaryKey(secret: projectSecret, bridgeId: bridgeId, projectId: projectId);
    final projectRepository = _FakeProjectRepository(paths: {projectId: "/projects/full"});
    final glossaryRepository = _FakeProjectGlossaryRepository(
      existingWords: {
        projectKey: [for (var index = 0; index < 50; index++) "Word$index"],
      },
      source: null,
      getWordsCallback: null,
    );
    final service = ProjectGlossaryService(
      keyMaterialProvider: keyMaterialProvider,
      projectRepository: projectRepository,
      glossaryRepository: glossaryRepository,
      termCalculator: const ProjectGlossaryTermCalculator(),
    );

    service.schedule(projectId: projectId);
    await service.drain();

    expect(projectRepository.resolveCalls, 1);
    expect(glossaryRepository.loadSourceCalls, 0);
    expect(glossaryRepository.addedWords, isEmpty);
  });

  test("rejects population when bridge-local key material is unavailable", () async {
    final glossaryRepository = _FakeProjectGlossaryRepository(
      existingWords: const {},
      source: null,
      getWordsCallback: null,
    );
    final service = ProjectGlossaryService(
      keyMaterialProvider: const _TestKeyMaterialProvider("br_test1234", null),
      projectRepository: _FakeProjectRepository(paths: {"project": "/projects/project"}),
      glossaryRepository: glossaryRepository,
      termCalculator: const ProjectGlossaryTermCalculator(),
    );

    expect(service.schedule(projectId: "project"), isNull);
    await service.drain();

    expect(glossaryRepository.getWordsProjectKeys, isEmpty);
  });

  test("a failed best-effort attempt does not retry during the same bridge process", () async {
    final glossaryRepository = _FakeProjectGlossaryRepository(
      existingWords: const {},
      source: null,
      getWordsCallback: ({required String projectKey}) async => throw StateError("server unavailable"),
    );
    final service = ProjectGlossaryService(
      keyMaterialProvider: keyMaterialProvider,
      projectRepository: _FakeProjectRepository(paths: {"project": "/projects/project"}),
      glossaryRepository: glossaryRepository,
      termCalculator: const ProjectGlossaryTermCalculator(),
    );

    service.schedule(projectId: "project");
    service.schedule(projectId: "project");
    await service.drain();

    expect(glossaryRepository.getWordsProjectKeys, hasLength(1));
  });
}

class const _TestKeyMaterialProvider(
  @override final String? bridgeId,
  @override final List<int>? projectGlossarySecret,
) implements ProjectGlossaryKeyMaterialProvider;

class _FakeProjectRepository({required final Map<String, String> paths}) implements ProjectRepository {
  int resolveCalls = 0;

  @override
  Future<String> resolveProjectDirectory({required String projectId}) async {
    resolveCalls++;
    return paths[projectId]!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProjectGlossaryRepository({
  required final Map<String, List<String>> existingWords,
  required final ProjectGlossarySource? source,
  required final Future<List<String>> Function({required String projectKey})? getWordsCallback,
}) implements ProjectGlossaryRepository {
  final List<String> getWordsProjectKeys = [];
  final List<AbortSignal> abortSignals = [];
  String? addedProjectKey;
  List<String> addedWords = [];
  int loadSourceCalls = 0;

  @override
  Future<List<String>> getWords({
    required String projectKey,
    required AbortSignal abortSignal,
  }) async {
    getWordsProjectKeys.add(projectKey);
    abortSignals.add(abortSignal);
    final callback = getWordsCallback;
    if (callback != null) return await callback(projectKey: projectKey);
    return existingWords[projectKey] ?? const [];
  }

  @override
  Future<ProjectGlossarySource> loadSource({required String projectPath}) async {
    loadSourceCalls++;
    return source ??
        ProjectGlossarySource(
          projectName: projectPath.split("/").last,
          repositoryName: null,
          trackedPaths: const ["lib/QuasarEngine.dart"],
          metadataDocuments: const [],
        );
  }

  @override
  Future<List<String>> addWords({
    required String projectKey,
    required List<String> words,
    required AbortSignal abortSignal,
  }) async {
    abortSignals.add(abortSignal);
    addedProjectKey = projectKey;
    addedWords = words;
    return words;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
