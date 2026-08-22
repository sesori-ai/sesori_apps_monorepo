import "dart:async";

import "package:sesori_bridge/src/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/repositories/project_repository.dart";
import "package:sesori_bridge/src/services/project_activity_service.dart";
import "package:sesori_bridge/src/services/project_initialization_service.dart";
import "package:sesori_bridge/src/services/project_mutation_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ProjectMutationService", () {
    test("runs complete create and open workflows in FIFO order without overlap", () async {
      final fixture = _Fixture();
      final createGate = Completer<void>();
      fixture.initialization.initializeGate = createGate;

      final create = fixture.service.createProject(path: "/created");
      await fixture.initialization.initializeStarted.future;
      final open = fixture.service.openProject(
        path: "/opened",
        gitAction: OpenProjectGitAction.initializeGit,
      );
      await Future<void>.delayed(Duration.zero);

      expect(fixture.events, ["initialize:/created"]);

      createGate.complete();
      expect((await create).id, "/created");
      expect(
        await open,
        isA<OpenProjectSuccess>().having((outcome) => outcome.project.id, "project id", "/opened"),
      );
      expect(fixture.events, [
        "initialize:/created",
        "open:/created",
        "classify:/opened",
        "prepare:/opened:initializeGit",
        "open:/opened",
      ]);
    });

    test("returns distinct open outcomes before persistence", () async {
      final fixture = _Fixture();
      fixture.filesystem.kinds.addAll({
        "/missing": FilesystemEntityKind.notFound,
        "/file": FilesystemEntityKind.notDirectory,
      });
      fixture.initialization.preparations["/choice"] = ExistingProjectPreparationOutcome.gitChoiceRequired;

      expect(
        await fixture.service.openProject(
          path: "/missing",
          gitAction: OpenProjectGitAction.promptIfNeeded,
        ),
        isA<OpenProjectDirectoryNotFound>(),
      );
      expect(
        await fixture.service.openProject(
          path: "/file",
          gitAction: OpenProjectGitAction.promptIfNeeded,
        ),
        isA<OpenProjectPathNotDirectory>(),
      );
      expect(
        await fixture.service.openProject(
          path: "/choice",
          gitAction: OpenProjectGitAction.promptIfNeeded,
        ),
        isA<OpenProjectGitChoiceRequired>(),
      );
      expect(fixture.activity.openedPaths, isEmpty);
    });

    test("open followed by hide finishes hidden", () async {
      final fixture = _Fixture();
      final openGate = Completer<void>();
      fixture.activity.openGate = openGate;

      final open = fixture.service.openProject(
        path: "/project",
        gitAction: OpenProjectGitAction.openWithoutGit,
      );
      await fixture.activity.openStarted.future;
      final hide = fixture.service.hideProject(projectId: "/project");
      await Future<void>.delayed(Duration.zero);

      expect(fixture.projects.hideCalls, isEmpty);
      openGate.complete();
      await Future.wait([open, hide]);
      expect(fixture.projects.hidden, isTrue);
      expect(fixture.events, [
        "classify:/project",
        "prepare:/project:openWithoutGit",
        "open:/project",
        "hide:/project",
      ]);
    });

    test("hide followed by open finishes visible", () async {
      final fixture = _Fixture();
      final hideGate = Completer<void>();
      fixture.projects.hideGate = hideGate;

      final hide = fixture.service.hideProject(projectId: "/project");
      await fixture.projects.hideStarted.future;
      final open = fixture.service.openProject(
        path: "/project",
        gitAction: OpenProjectGitAction.openWithoutGit,
      );
      await Future<void>.delayed(Duration.zero);

      expect(fixture.filesystem.classifiedPaths, isEmpty);
      hideGate.complete();
      await Future.wait([hide, open]);
      expect(fixture.projects.hidden, isFalse);
      expect(fixture.events, [
        "hide:/project",
        "classify:/project",
        "prepare:/project:openWithoutGit",
        "open:/project",
      ]);
    });

    test("a failed workflow releases the FIFO for later work", () async {
      final fixture = _Fixture();
      final failure = StateError("Git setup failed");
      fixture.initialization.initializeError = failure;

      final create = fixture.service.createProject(path: "/failed");
      final hide = fixture.service.hideProject(projectId: "/later");

      await expectLater(create, throwsA(same(failure)));
      await hide;
      expect(fixture.projects.hideCalls, ["/later"]);
      expect(fixture.events, ["initialize:/failed", "hide:/later"]);
    });
  });
}

class _Fixture() {
  final List<String> events = [];
  late final _FilesystemRepository filesystem = _FilesystemRepository(events: events);
  late final _ProjectInitializationService initialization = _ProjectInitializationService(events: events);
  late final _ProjectRepository projects = _ProjectRepository(events: events);
  late final _ProjectActivityService activity = _ProjectActivityService(
    events: events,
    projects: projects,
  );
  late final ProjectMutationService service = ProjectMutationService(
    filesystemRepository: filesystem,
    projectInitializationService: initialization,
    projectActivityService: activity,
    projectRepository: projects,
  );
}

class _FilesystemRepository({required final List<String> events}) implements FilesystemRepository {
  final Map<String, FilesystemEntityKind> kinds = {};
  final List<String> classifiedPaths = [];

  @override
  FilesystemEntityKind classifyPath({required String path}) {
    events.add("classify:$path");
    classifiedPaths.add(path);
    return kinds[path] ?? FilesystemEntityKind.directory;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProjectInitializationService({required final List<String> events}) implements ProjectInitializationService {
  final Completer<void> initializeStarted = Completer<void>();
  final Map<String, ExistingProjectPreparationOutcome> preparations = {};
  Completer<void>? initializeGate;
  Object? initializeError;

  @override
  Future<void> initializeProject({required String path}) async {
    events.add("initialize:$path");
    if (!initializeStarted.isCompleted) initializeStarted.complete();
    final gate = initializeGate;
    if (gate != null) await gate.future;
    final error = initializeError;
    if (error != null) throw error;
  }

  @override
  Future<ExistingProjectPreparationOutcome> prepareExistingProject({
    required String path,
    required OpenProjectGitAction gitAction,
  }) async {
    events.add("prepare:$path:${gitAction.name}");
    return preparations[path] ?? ExistingProjectPreparationOutcome.ready;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProjectActivityService({required final List<String> events, required final _ProjectRepository projects})
    implements ProjectActivityService {
  final Completer<void> openStarted = Completer<void>();
  final List<String> openedPaths = [];
  Completer<void>? openGate;

  @override
  Future<Project> openProject({required String path}) async {
    events.add("open:$path");
    openedPaths.add(path);
    if (!openStarted.isCompleted) openStarted.complete();
    final gate = openGate;
    if (gate != null) await gate.future;
    projects.hidden = false;
    return Project(
      id: path,
      name: path,
      path: path,
      time: null,
      supportsDedicatedWorktrees: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProjectRepository({required final List<String> events}) implements ProjectRepository {
  final Completer<void> hideStarted = Completer<void>();
  final List<String> hideCalls = [];
  Completer<void>? hideGate;
  bool hidden = false;

  @override
  Future<void> hideProject({required String projectId}) async {
    events.add("hide:$projectId");
    hideCalls.add(projectId);
    if (!hideStarted.isCompleted) hideStarted.complete();
    final gate = hideGate;
    if (gate != null) await gate.future;
    hidden = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
