import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("CatalogImportRequest round-trips through JSON", () {
    const original = CatalogImportRequest(pluginId: "codex");

    final json = original.toJson();

    expect(json, {"pluginId": "codex"});
    expect(CatalogImportRequest.fromJson(json), original);
  });

  group("CatalogImportProgress", () {
    late Map<String, CatalogImportProgress> variants;

    setUp(() {
      variants = {
        "enumerating": const CatalogImportProgress.enumerating(
          pluginId: "codex",
          projectsSeen: 2,
          sessionsSeen: 5,
        ),
        "committing": const CatalogImportProgress.committing(
          pluginId: "codex",
          projectsSeen: 3,
          sessionsSeen: 8,
        ),
        "completed": const CatalogImportProgress.completed(
          pluginId: "codex",
          projectsImported: 3,
          sessionsImported: 8,
          completedAt: 1_752_750_600_000,
        ),
        "cancelled": const CatalogImportProgress.cancelled(pluginId: "codex"),
        "failed": const CatalogImportProgress.failed(pluginId: "codex", message: "catalog unavailable"),
      };
    });

    test("all phases round-trip with their discriminator", () {
      for (final MapEntry(key: type, value: original) in variants.entries) {
        final json = original.toJson();

        expect(json["type"], type);
        expect(CatalogImportProgress.fromJson(json), original);
      }
    });

    test("completed serializes its epoch-millisecond timestamp", () {
      final json = variants["completed"]!.toJson();

      expect(json["completedAt"], 1_752_750_600_000);
    });

    test("statuses response round-trips every phase", () {
      final original = CatalogImportStatusesResponse(statuses: variants.values.toList());

      final json = original.toJson();

      expect(CatalogImportStatusesResponse.fromJson(json), original);
    });

    test("SSE event round-trips progress as a global event", () {
      final original = SesoriSseEvent.catalogImportProgress(progress: variants["completed"]!);

      final json = original.toJson();

      expect(json["type"], "catalog.import.progress");
      expect(SesoriSseEvent.fromJson(json), original);
      expect(original, isNot(isA<SesoriSessionEvent>()));
    });
  });
}
