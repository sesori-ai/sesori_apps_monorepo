import "dart:async";

import "package:sesori_bridge/src/api/database/tables/catalog_hydrations_table.dart";
import "package:sesori_bridge/src/listeners/plugin_catalog_hydration_listener.dart";
import "package:sesori_bridge/src/repositories/catalog_import_repository.dart";
import "package:sesori_bridge/src/repositories/models/catalog_import_control.dart";
import "package:sesori_bridge/src/services/catalog_import_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  CatalogImportService createService({
    required CatalogImportRepository repository,
    required CatalogEmptyHydrationPolicy policy,
  }) {
    return CatalogImportService(
      repository: repository,
      orderedPluginIds: const ["selected", "other"],
      emptyHydrationPolicies: {"selected": policy, "other": policy},
    );
  }

  group("CatalogImportService", () {
    test("rejects unknown and unselected plugins synchronously before repository access", () {
      final repository = _FakeCatalogImportRepository(
        completion: null,
        hydrationGate: null,
        releaseImport: null,
        importError: null,
        eligiblePluginIds: null,
        importEligiblePluginIds: null,
      );
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.complete,
      );

      expect(
        () => service.start(pluginId: "other", trigger: CatalogImportTrigger.explicit),
        throwsA(isA<CatalogImportPluginNotEnabledException>()),
      );
      expect(() => service.cancel(pluginId: "other"), throwsA(isA<CatalogImportPluginNotEnabledException>()));
      expect(() => service.cancel(pluginId: "unknown"), throwsA(isA<CatalogImportPluginUnknownException>()));
      expect(repository.hydrationReads, 0);
      expect(repository.importCalls, 0);
    });

    test("an existing marker skips an automatic request without publishing progress", () async {
      final repository = _FakeCatalogImportRepository(
        completion: const CatalogHydrationDto(
          pluginId: "selected",
          projectionVersion: CatalogImportRepository.projectionVersion,
          completedAt: 1234,
        ),
        hydrationGate: null,
        releaseImport: null,
        importError: null,
        eligiblePluginIds: null,
        importEligiblePluginIds: null,
      );
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.complete,
      );
      addTearDown(service.dispose);
      final progress = <CatalogImportProgress>[];
      final subscription = service.progress.listen(progress.add);
      addTearDown(subscription.cancel);

      service.start(pluginId: "selected", trigger: CatalogImportTrigger.automatic);
      await pumpEventQueue();

      expect(repository.hydrationReads, 1);
      expect(repository.importCalls, 0);
      expect(progress, isEmpty);
      expect(service.latestStatuses, isEmpty);
    });

    test("overlapping automatic and explicit starts join and combine control", () async {
      final hydrationGate = Completer<CatalogHydrationDto?>();
      final releaseImport = Completer<void>();
      final repository = _FakeCatalogImportRepository(
        completion: null,
        hydrationGate: hydrationGate,
        releaseImport: releaseImport,
        importError: null,
        eligiblePluginIds: null,
        importEligiblePluginIds: null,
      );
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.complete,
      );
      addTearDown(service.dispose);
      final completed = service.progress.firstWhere((status) => status is CatalogImportCompleted);

      service.start(pluginId: "selected", trigger: CatalogImportTrigger.automatic);
      service.start(pluginId: "selected", trigger: CatalogImportTrigger.explicit);
      hydrationGate.complete(
        const CatalogHydrationDto(
          pluginId: "selected",
          projectionVersion: CatalogImportRepository.projectionVersion,
          completedAt: 100,
        ),
      );
      await repository.importStarted.future;

      expect(repository.importCalls, 1);
      expect(repository.lastControl?.explicitImportRequested, isTrue);
      expect(repository.lastControl?.hydrationMarkerRequested, isTrue);
      releaseImport.complete();
      await completed;
    });

    test("cancellation produces a truthful terminal status", () async {
      final releaseImport = Completer<void>();
      final repository = _FakeCatalogImportRepository(
        completion: null,
        hydrationGate: null,
        releaseImport: releaseImport,
        importError: null,
        eligiblePluginIds: null,
        importEligiblePluginIds: null,
      );
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.complete,
      );
      addTearDown(service.dispose);
      final cancelled = service.progress.firstWhere((status) => status is CatalogImportCancelled);

      service.start(pluginId: "selected", trigger: CatalogImportTrigger.explicit);
      await repository.importStarted.future;
      service.cancel(pluginId: "selected");
      releaseImport.complete();

      await cancelled;
      expect(service.latestStatuses.single, isA<CatalogImportCancelled>());
    });

    test("cancels an active import after its plugin becomes unavailable", () async {
      final releaseImport = Completer<void>();
      final eligiblePluginIds = <String>{"selected"};
      final importEligiblePluginIds = <String>{"selected"};
      final repository = _FakeCatalogImportRepository(
        completion: null,
        hydrationGate: null,
        releaseImport: releaseImport,
        importError: null,
        eligiblePluginIds: eligiblePluginIds,
        importEligiblePluginIds: importEligiblePluginIds,
      );
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.complete,
      );
      final cancelled = service.progress.firstWhere((status) => status is CatalogImportCancelled);
      service.start(pluginId: "selected", trigger: CatalogImportTrigger.explicit);
      await repository.importStarted.future;

      eligiblePluginIds.remove("selected");
      importEligiblePluginIds.remove("selected");
      Object? cancellationError;
      try {
        service.cancel(pluginId: "selected");
      } on Object catch (error) {
        cancellationError = error;
      }
      releaseImport.complete();
      await service.dispose();

      expect(cancellationError, isNull);
      expect(await cancelled, isA<CatalogImportCancelled>());
    });

    test("repository errors become one failed terminal status", () async {
      final repository = _FakeCatalogImportRepository(
        completion: null,
        hydrationGate: null,
        releaseImport: null,
        importError: StateError("enumeration failed"),
        eligiblePluginIds: null,
        importEligiblePluginIds: null,
      );
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.complete,
      );
      addTearDown(service.dispose);
      final statuses = <CatalogImportProgress>[];
      final subscription = service.progress.listen(statuses.add);
      addTearDown(subscription.cancel);

      service.start(pluginId: "selected", trigger: CatalogImportTrigger.explicit);
      await service.progress.firstWhere((status) => status is CatalogImportFailed);

      expect(statuses.whereType<CatalogImportFailed>(), hasLength(1));
      expect((service.latestStatuses.single as CatalogImportFailed).message, contains("enumeration failed"));
    });

    test("ready-id additions hydrate a plugin enabled after startup", () async {
      final eligiblePluginIds = <String>{};
      final importEligiblePluginIds = <String>{};
      final repository = _FakeCatalogImportRepository(
        completion: null,
        hydrationGate: null,
        releaseImport: null,
        importError: null,
        eligiblePluginIds: eligiblePluginIds,
        importEligiblePluginIds: importEligiblePluginIds,
      );
      final service = createService(repository: repository, policy: CatalogEmptyHydrationPolicy.complete);
      final readyPluginIds = StreamController<List<String>>.broadcast(sync: true);
      final listener = PluginCatalogHydrationListener(
        readyPluginIds: readyPluginIds.stream,
        catalogImportService: service,
      )..start();
      addTearDown(() async {
        await listener.dispose();
        await readyPluginIds.close();
        await service.dispose();
      });
      readyPluginIds.add(const []);

      eligiblePluginIds.add("selected");
      importEligiblePluginIds.add("selected");
      final completed = service.progress.firstWhere((status) => status is CatalogImportCompleted);
      readyPluginIds.add(const ["selected"]);

      await completed;
      expect(repository.importCalls, 1);
      eligiblePluginIds.remove("selected");
      expect(service.latestStatuses, isEmpty);
    });

    test("an empty derived import remains eligible for automatic retry", () async {
      final repository = _FakeCatalogImportRepository(
        completion: null,
        hydrationGate: null,
        releaseImport: null,
        importError: null,
        eligiblePluginIds: null,
        importEligiblePluginIds: null,
      );
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.retry,
      );
      addTearDown(service.dispose);

      service.start(pluginId: "selected", trigger: CatalogImportTrigger.automatic);
      await service.progress.firstWhere((status) => status is CatalogImportCompleted);

      expect(repository.lastControl?.hydrationMarkerRequested, isFalse);
    });

    test("concurrent dispose callers share one teardown", () async {
      final releaseImport = Completer<void>();
      final repository = _FakeCatalogImportRepository(
        completion: null,
        hydrationGate: null,
        releaseImport: releaseImport,
        importError: null,
        eligiblePluginIds: null,
        importEligiblePluginIds: null,
      );
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.complete,
      );
      service.start(pluginId: "selected", trigger: CatalogImportTrigger.explicit);
      await repository.importStarted.future;

      final first = service.dispose();
      final second = service.dispose();

      expect(identical(first, second), isTrue);
      releaseImport.complete();
      await Future.wait([first, second]);
    });
  });
}

class _FakeCatalogImportRepository({
  required final CatalogHydrationDto? completion,
  required final Completer<CatalogHydrationDto?>? hydrationGate,
  required final Completer<void>? releaseImport,
  required final Object? importError,
  required Set<String>? eligiblePluginIds,
  required Set<String>? importEligiblePluginIds,
}) implements CatalogImportRepository {
  @override
  Stream<List<SessionBackendActivity>> get backendActivity => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  final Set<String> eligiblePluginIds = eligiblePluginIds ?? <String>{"selected"};
  @override
  final Set<String> importEligiblePluginIds = importEligiblePluginIds ?? eligiblePluginIds ?? <String>{"selected"};
  final Completer<void> importStarted = Completer<void>();

  int hydrationReads = 0;
  int importCalls = 0;
  CatalogImportControl? lastControl;

  @override
  Future<CatalogHydrationDto?> getHydrationCompletion({required String pluginId}) async {
    hydrationReads++;
    return await (hydrationGate == null ? completion : hydrationGate!.future);
  }

  @override
  Stream<CatalogImportProgress> importCatalog({
    required String pluginId,
    required CatalogImportControl control,
  }) async* {
    importCalls++;
    lastControl = control;
    if (!importStarted.isCompleted) importStarted.complete();
    yield const CatalogImportProgress.enumerating(
      pluginId: "selected",
      projectsSeen: 0,
      sessionsSeen: 0,
    );
    await releaseImport?.future;
    if (importError case final error?) throw error;
    if (control.cancellationRequested) {
      yield const CatalogImportProgress.cancelled(pluginId: "selected");
      return;
    }
    yield const CatalogImportProgress.committing(
      pluginId: "selected",
      projectsSeen: 1,
      sessionsSeen: 0,
    );
    yield const CatalogImportProgress.completed(
      pluginId: "selected",
      projectsImported: 1,
      sessionsImported: 2,
      newItems: CatalogImportNewItems(projects: 1, sessions: 2),
      completedAt: 200,
    );
  }
}
