import "dart:async";
import "dart:convert";

import "package:sesori_bridge/src/api/database/tables/catalog_hydrations_table.dart";
import "package:sesori_bridge/src/repositories/catalog_import_repository.dart";
import "package:sesori_bridge/src/repositories/models/catalog_import_control.dart";
import "package:sesori_bridge/src/routing/cancel_catalog_import_handler.dart";
import "package:sesori_bridge/src/routing/get_catalog_import_statuses_handler.dart";
import "package:sesori_bridge/src/routing/start_catalog_import_handler.dart";
import "package:sesori_bridge/src/services/catalog_import_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../bridge/routing/routing_test_helpers.dart";

void main() {
  CatalogImportService createService(CatalogImportRepository repository) {
    return CatalogImportService(
      repository: repository,
      knownPluginIds: const {"selected", "other"},
      enabledPluginIds: const ["selected"],
      emptyHydrationPolicies: const {"selected": CatalogEmptyHydrationPolicy.complete},
    );
  }

  group("catalog import handlers", () {
    test("POST starts the selected import and GET returns its latest status", () async {
      final repository = _HandlerCatalogImportRepository();
      final service = createService(repository);
      addTearDown(service.dispose);
      final handler = StartCatalogImportHandler(service: service);
      final completed = service.progress.firstWhere((status) => status is CatalogImportCompleted);

      final response = await handler.handleInternal(
        makeRequest(
          "POST",
          "/plugin/import",
          body: jsonEncode(const CatalogImportRequest(pluginId: "selected").toJson()),
        ),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );

      expect(response.status, 200);
      await completed;
      final getResponse = await GetCatalogImportStatusesHandler(service: service).handleInternal(
        makeRequest("GET", "/plugin/import"),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );
      final decoded = CatalogImportStatusesResponse.fromJson(jsonDecodeMap(getResponse.body!));
      expect(decoded.statuses.single, isA<CatalogImportCompleted>());
      expect(repository.importCalls, 1);
    });

    test("POST and DELETE map an unselected plugin to 404", () async {
      final service = createService(_HandlerCatalogImportRepository());
      addTearDown(service.dispose);
      final requestBody = jsonEncode(const CatalogImportRequest(pluginId: "other").toJson());

      final postResponse = await StartCatalogImportHandler(service: service).handleInternal(
        makeRequest("POST", "/plugin/import", body: requestBody),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );
      final deleteResponse = await CancelCatalogImportHandler(service: service).handleInternal(
        makeRequest("DELETE", "/plugin/import", body: requestBody),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );

      expect(postResponse.status, 404);
      expect(deleteResponse.status, 404);
    });

    test("DELETE requests cooperative cancellation", () async {
      final release = Completer<void>();
      final repository = _HandlerCatalogImportRepository(release: release);
      final service = createService(repository);
      addTearDown(service.dispose);
      final cancelled = service.progress.firstWhere((status) => status is CatalogImportCancelled);
      service.start(pluginId: "selected", trigger: CatalogImportTrigger.explicit);
      await repository.started.future;

      final response = await CancelCatalogImportHandler(service: service).handleInternal(
        makeRequest(
          "DELETE",
          "/plugin/import",
          body: jsonEncode(const CatalogImportRequest(pluginId: "selected").toJson()),
        ),
        pathParams: const {},
        queryParams: const {},
        fragment: null,
      );
      release.complete();

      expect(response.status, 200);
      await cancelled;
      expect(repository.control?.cancellationRequested, isTrue);
    });
  });
}

class _HandlerCatalogImportRepository implements CatalogImportRepository {
  _HandlerCatalogImportRepository({this.release});

  final Completer<void>? release;
  final Completer<void> started = Completer<void>();
  int importCalls = 0;
  CatalogImportControl? control;

  @override
  Set<String> get importEligiblePluginIds => const {"selected"};

  @override
  Future<CatalogHydrationDto?> getHydrationCompletion({required String pluginId}) async => null;

  @override
  Stream<CatalogImportProgress> importCatalog({
    required String pluginId,
    required CatalogImportControl control,
  }) async* {
    importCalls++;
    this.control = control;
    if (!started.isCompleted) started.complete();
    yield const CatalogImportProgress.enumerating(
      pluginId: "selected",
      projectsSeen: 0,
      sessionsSeen: 0,
    );
    await release?.future;
    if (control.cancellationRequested) {
      yield const CatalogImportProgress.cancelled(pluginId: "selected");
    } else {
      yield const CatalogImportProgress.completed(
        pluginId: "selected",
        projectsImported: 0,
        sessionsImported: 0,
        completedAt: 1,
      );
    }
  }
}
