import "dart:async";

import "package:sesori_bridge/src/api/database/tables/catalog_hydrations_table.dart";
import "package:sesori_bridge/src/repositories/catalog_import_repository.dart";
import "package:sesori_bridge/src/repositories/models/catalog_import_control.dart";
import "package:sesori_bridge/src/services/catalog_import_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  CatalogImportService createService({
    required CatalogImportRepository repository,
    required CatalogEmptyHydrationPolicy policy,
    Set<String>? eligiblePluginIds,
  }) {
    final eligibleIds = eligiblePluginIds ?? <String>{"selected"};
    return CatalogImportService(
      repository: repository,
      knownPluginIds: const {"selected", "other"},
      readEligiblePluginIds: () => [
        for (final pluginId in ["selected", "other"])
          if (eligibleIds.contains(pluginId)) pluginId,
      ],
      readEmptyHydrationPolicy: (pluginId) => policy,
    );
  }

  group("CatalogImportService", () {
    test("rejects unknown and unselected plugins synchronously before repository access", () {
      final repository = _FakeCatalogImportRepository();
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

    test("an existing marker completes an automatic request without enumeration", () async {
      final repository = _FakeCatalogImportRepository(
        completion: const CatalogHydrationDto(
          pluginId: "selected",
          projectionVersion: CatalogImportRepository.projectionVersion,
          completedAt: 1234,
        ),
      );
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.complete,
      );
      addTearDown(service.dispose);
      final completed = service.progress.firstWhere((status) => status is CatalogImportCompleted);

      service.start(pluginId: "selected", trigger: CatalogImportTrigger.automatic);

      expect(
        await completed,
        isA<CatalogImportCompleted>().having((status) => status.completedAt, "completedAt", 1234),
      );
      expect(repository.importCalls, 0);
      expect(service.latestStatuses.single, isA<CatalogImportCompleted>());
    });

    test("newly enabled plugins use live eligibility and hydration policy", () async {
      final eligiblePluginIds = <String>{"selected"};
      final repository = _FakeCatalogImportRepository(eligiblePluginIds: <String>{"selected", "other"});
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.retry,
        eligiblePluginIds: eligiblePluginIds,
      );
      addTearDown(service.dispose);

      expect(
        () => service.start(pluginId: "other", trigger: CatalogImportTrigger.automatic),
        throwsA(isA<CatalogImportPluginNotEnabledException>()),
      );
      eligiblePluginIds.add("other");
      service.start(pluginId: "other", trigger: CatalogImportTrigger.automatic);
      await service.progress.firstWhere((status) => status.pluginId == "other" && status is CatalogImportCompleted);

      expect(service.latestStatuses.map((status) => status.pluginId), contains("other"));
      expect(repository.lastControl?.hydrationMarkerRequested, isFalse);
    });

    test("overlapping automatic and headless starts join and combine control", () async {
      final hydrationGate = Completer<CatalogHydrationDto?>();
      final releaseImport = Completer<void>();
      final repository = _FakeCatalogImportRepository(
        hydrationGate: hydrationGate,
        releaseImport: releaseImport,
      );
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.complete,
      );
      addTearDown(service.dispose);
      final completed = service.progress.firstWhere((status) => status is CatalogImportCompleted);

      service.start(pluginId: "selected", trigger: CatalogImportTrigger.automatic);
      service.start(pluginId: "selected", trigger: CatalogImportTrigger.headless);
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
      final repository = _FakeCatalogImportRepository(releaseImport: releaseImport);
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
      final repository = _FakeCatalogImportRepository(
        releaseImport: releaseImport,
        eligiblePluginIds: eligiblePluginIds,
      );
      final service = createService(
        repository: repository,
        policy: CatalogEmptyHydrationPolicy.complete,
      );
      service.start(pluginId: "selected", trigger: CatalogImportTrigger.explicit);
      await repository.importStarted.future;

      eligiblePluginIds.remove("selected");
      Object? cancellationError;
      try {
        service.cancel(pluginId: "selected");
      } on Object catch (error) {
        cancellationError = error;
      }
      releaseImport.complete();
      await service.dispose();

      expect(cancellationError, isNull);
      expect(service.latestStatuses.single, isA<CatalogImportCancelled>());
    });

    test("repository errors become one failed terminal status", () async {
      final repository = _FakeCatalogImportRepository(importError: StateError("enumeration failed"));
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

    test("an empty derived import remains eligible for automatic retry", () async {
      final repository = _FakeCatalogImportRepository();
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
      final repository = _FakeCatalogImportRepository(releaseImport: releaseImport);
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

class _FakeCatalogImportRepository implements CatalogImportRepository {
  _FakeCatalogImportRepository({
    this.completion,
    this.hydrationGate,
    this.releaseImport,
    this.importError,
    Set<String>? eligiblePluginIds,
  }) : importEligiblePluginIds = eligiblePluginIds ?? <String>{"selected"};

  final CatalogHydrationDto? completion;
  final Completer<CatalogHydrationDto?>? hydrationGate;
  final Completer<void>? releaseImport;
  final Object? importError;
  @override
  final Set<String> importEligiblePluginIds;
  final Completer<void> importStarted = Completer<void>();

  int hydrationReads = 0;
  int importCalls = 0;
  CatalogImportControl? lastControl;

  @override
  Future<CatalogHydrationDto?> getHydrationCompletion({required String pluginId}) async {
    hydrationReads++;
    return hydrationGate == null ? completion : hydrationGate!.future;
  }

  @override
  Stream<CatalogImportProgress> importCatalog({
    required String pluginId,
    required CatalogImportControl control,
  }) async* {
    importCalls++;
    lastControl = control;
    if (!importStarted.isCompleted) importStarted.complete();
    yield CatalogImportProgress.enumerating(
      pluginId: pluginId,
      projectsSeen: 0,
      sessionsSeen: 0,
    );
    await releaseImport?.future;
    if (importError case final error?) throw error;
    if (control.cancellationRequested) {
      yield CatalogImportProgress.cancelled(pluginId: pluginId);
      return;
    }
    yield CatalogImportProgress.committing(
      pluginId: pluginId,
      projectsSeen: 1,
      sessionsSeen: 0,
    );
    yield CatalogImportProgress.completed(
      pluginId: pluginId,
      projectsImported: 1,
      sessionsImported: 2,
      completedAt: 200,
    );
  }
}
