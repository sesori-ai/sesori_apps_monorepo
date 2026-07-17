import "dart:async";

import "package:sesori_bridge/src/api/database/tables/catalog_hydrations_table.dart";
import "package:sesori_bridge/src/repositories/catalog_import_repository.dart";
import "package:sesori_bridge/src/repositories/models/catalog_import_control.dart";
import "package:sesori_bridge/src/services/catalog_import_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("CatalogImportService", () {
    test("rejects an unselected plugin synchronously before repository access", () {
      final repository = _FakeCatalogImportRepository();
      final service = CatalogImportService(repository: repository);

      expect(
        () => service.start(pluginId: "other", trigger: CatalogImportTrigger.explicit),
        throwsA(isA<CatalogImportPluginNotSelectedException>()),
      );
      expect(() => service.cancel(pluginId: "other"), throwsA(isA<CatalogImportPluginNotSelectedException>()));
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
      final service = CatalogImportService(repository: repository);
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

    test("overlapping automatic and headless starts join and combine control", () async {
      final hydrationGate = Completer<CatalogHydrationDto?>();
      final releaseImport = Completer<void>();
      final repository = _FakeCatalogImportRepository(
        hydrationGate: hydrationGate,
        releaseImport: releaseImport,
      );
      final service = CatalogImportService(repository: repository);
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
      final service = CatalogImportService(repository: repository);
      addTearDown(service.dispose);
      final cancelled = service.progress.firstWhere((status) => status is CatalogImportCancelled);

      service.start(pluginId: "selected", trigger: CatalogImportTrigger.explicit);
      await repository.importStarted.future;
      service.cancel(pluginId: "selected");
      releaseImport.complete();

      await cancelled;
      expect(service.latestStatuses.single, isA<CatalogImportCancelled>());
    });

    test("repository errors become one failed terminal status", () async {
      final repository = _FakeCatalogImportRepository(importError: StateError("enumeration failed"));
      final service = CatalogImportService(repository: repository);
      addTearDown(service.dispose);
      final statuses = <CatalogImportProgress>[];
      final subscription = service.progress.listen(statuses.add);
      addTearDown(subscription.cancel);

      service.start(pluginId: "selected", trigger: CatalogImportTrigger.explicit);
      await service.progress.firstWhere((status) => status is CatalogImportFailed);

      expect(statuses.whereType<CatalogImportFailed>(), hasLength(1));
      expect((service.latestStatuses.single as CatalogImportFailed).message, contains("enumeration failed"));
    });
  });
}

class _FakeCatalogImportRepository implements CatalogImportRepository {
  _FakeCatalogImportRepository({
    this.completion,
    this.hydrationGate,
    this.releaseImport,
    this.importError,
  });

  final CatalogHydrationDto? completion;
  final Completer<CatalogHydrationDto?>? hydrationGate;
  final Completer<void>? releaseImport;
  final Object? importError;
  final Completer<void> importStarted = Completer<void>();

  int hydrationReads = 0;
  int importCalls = 0;
  CatalogImportControl? lastControl;

  @override
  String get pluginId => "selected";

  @override
  Future<CatalogHydrationDto?> getHydrationCompletion() async {
    hydrationReads++;
    return hydrationGate == null ? completion : hydrationGate!.future;
  }

  @override
  Stream<CatalogImportProgress> importCatalog({required CatalogImportControl control}) async* {
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
    yield const CatalogImportProgress.completed(
      pluginId: "selected",
      projectsImported: 1,
      sessionsImported: 2,
      completedAt: 200,
    );
  }
}
