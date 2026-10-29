import "dart:io" as io;

import "package:path/path.dart" as path;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/open_code_catalog_database_api.dart";
import "open_code_catalog_snapshot_mapper.dart";

typedef OpenCodeCatalogFileExists = bool Function({required String path});

/// Layer-2 OpenCode catalog assembly over its read-only database API.
class OpenCodeCatalogRepository({
  required final OpenCodeCatalogDatabaseApi databaseApi,
  required final OpenCodeCatalogSnapshotMapper snapshotMapper,
  required final PlatformOs operatingSystem,
  required final OpenCodeCatalogFileExists fileExists,
  required final String? trustedInstallationChannel,
}) {
  Future<PluginCatalogSnapshotResult> read({
    required Map<String, String> environment,
    required PluginCatalogCancellationSignal cancellation,
  }) async {
    final databasePath = _resolveDatabasePath(environment: environment);
    if (databasePath == null || !fileExists(path: databasePath)) {
      return const PluginCatalogSnapshotUnavailable();
    }
    if (cancellation.isCancelled) throw const PluginStartAbortedException();
    final raw = await databaseApi.read(databasePath: databasePath);
    if (cancellation.isCancelled) throw const PluginStartAbortedException();
    final OpenCodeCatalogDatabaseSnapshot rows;
    switch (raw) {
      case OpenCodeCatalogDatabaseSnapshot():
        rows = raw;
      // An OpenCode 2.x database is not read here; the live import covers it.
      case OpenCodeCatalogDatabaseMigratedToV2():
        return const PluginCatalogSnapshotUnavailable();
    }
    final snapshot = await snapshotMapper.map(raw: rows, cancellation: cancellation);
    return PluginCatalogSnapshotAvailable(snapshot: snapshot);
  }

  String? _resolveDatabasePath({required Map<String, String> environment}) {
    final context = path.Context(
      style: operatingSystem == PlatformOs.windows ? path.Style.windows : path.Style.posix,
    );
    final override = environment["OPENCODE_DB"];
    if (override != null && override.isNotEmpty) {
      if (override == ":memory:") return null;
      if (context.isAbsolute(override)) return override;
      final dataRoot = _resolveDataRoot(environment: environment, context: context);
      return dataRoot == null ? null : context.join(dataRoot, override);
    }
    final dataRoot = _resolveDataRoot(environment: environment, context: context);
    if (dataRoot == null) return null;
    final disablesChannelDatabase = switch (environment["OPENCODE_DISABLE_CHANNEL_DB"]) {
      "1" || "true" => true,
      _ => false,
    };
    const publicChannels = {"latest", "beta", "prod"};
    if (!disablesChannelDatabase && !publicChannels.contains(trustedInstallationChannel)) return null;
    return context.join(dataRoot, "opencode.db");
  }

  String? _resolveDataRoot({
    required Map<String, String> environment,
    required path.Context context,
  }) {
    final xdg = environment["XDG_DATA_HOME"];
    if (xdg case final value? when value.isNotEmpty) {
      if (!context.isAbsolute(value)) return null;
      return context.join(value, "opencode");
    }
    final home = resolveUserHomeDirectory(environment: environment);
    if (home == null || home.isEmpty || !context.isAbsolute(home)) return null;
    return context.join(home, ".local", "share", "opencode");
  }
}

bool openCodeCatalogFileExists({required String path}) => io.File(path).existsSync();
