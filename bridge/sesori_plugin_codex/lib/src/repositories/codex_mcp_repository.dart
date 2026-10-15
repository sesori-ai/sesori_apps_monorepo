import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/codex_app_server_api.dart";
import "../api/models/codex_apps_dto.dart";
import "../api/models/codex_mcp_status_dto.dart";
import "mappers/codex_mcp_mapper.dart";

/// Retains unexpected decoder errors as typed native-read diagnostics.
final class const CodexMcpInventoryReadException({required final Object innerError}) implements Exception {
  @override
  String toString() => "Codex MCP inventory read failed: $innerError";
}

/// A complete read over the current transport, without starting agent work.
class CodexMcpRepository({required final CodexAppServerApi _appServerApi, required final CodexMcpMapper _mapper}) {
  Future<PluginMcpInventoryResult> read({required PluginMcpScope scope}) async {
    final servers = await readServers(scope: scope);
    final List<PluginMcpInventoryEntry> serverEntries;
    final PluginMcpCatalogAvailability serverAvailability;
    switch (servers) {
      case PluginMcpInventoryUnavailable():
        return servers;
      case PluginMcpInventorySnapshot(:final entries, :final servers):
        serverEntries = entries;
        serverAvailability = servers;
      case PluginMcpInventoryReadFailed(:final cause, :final causeStackTrace):
        final context = scope is PluginMcpSessionScope ? "thread ${scope.sessionId}" : "harness";
        Log.w("[codex] MCP server inventory unavailable in $context", cause, causeStackTrace);
        serverEntries = const [];
        serverAvailability = const PluginMcpCatalogUnavailable(message: "Server inventory is unavailable.");
    }
    final offers = await _readConnectorOffers(scope: scope);
    return PluginMcpInventorySnapshot(
      entries: List.unmodifiable([...serverEntries, ...offers.entries]),
      servers: serverAvailability,
      connectors: offers.availability,
    );
  }

  Future<({List<PluginMcpConnectorOfferSnapshot> entries, PluginMcpCatalogAvailability availability})>
  _readConnectorOffers({required PluginMcpScope scope}) async {
    final threadId = scope is PluginMcpSessionScope ? scope.sessionId : null;
    try {
      final apps = await _readApps(scope: scope);
      return (
        entries: _mapper.mapConnectorOffers(apps: apps, scope: scope),
        availability: const PluginMcpCatalogAvailable(),
      );
    } on Object catch (error, stackTrace) {
      Log.w(
        "[codex] Connector catalog unavailable in ${threadId == null ? 'harness' : 'thread $threadId'}",
        error,
        stackTrace,
      );
      return (
        entries: const <PluginMcpConnectorOfferSnapshot>[],
        availability: const PluginMcpCatalogUnavailable(message: "Connector catalog is unavailable."),
      );
    }
  }

  Future<List<CodexAppInfoDto>> _readApps({required PluginMcpScope scope}) async {
    final threadId = scope is PluginMcpSessionScope ? scope.sessionId : null;
    final apps = <CodexAppInfoDto>[];
    String? cursor;
    do {
      final page = await _appServerApi.listAppsPage(threadId: threadId, cursor: cursor);
      apps.addAll(page.data);
      cursor = page.nextCursor;
    } while (cursor != null);
    return apps;
  }

  Future<PluginMcpConnectorSetupResult> resolveSetup({required PluginMcpConnectorOfferTarget target}) async {
    if (target.scope is PluginMcpProjectScope) {
      return const PluginMcpConnectorSetupUnavailable(
        reason: PluginMcpConnectorSetupUnavailableReason.unsupportedScope,
      );
    }
    try {
      final apps = await _readApps(scope: target.scope);
      final app = apps.where((app) => app.id == target.offerKey).firstOrNull;
      if (app == null) {
        return const PluginMcpConnectorSetupUnavailable(
          reason: PluginMcpConnectorSetupUnavailableReason.targetNotFound,
        );
      }
      if (!app.isEnabled || app.isAccessible) {
        return const PluginMcpConnectorSetupUnavailable(reason: PluginMcpConnectorSetupUnavailableReason.notSupported);
      }
      final destination = _mapper.setupDestination(app: app);
      return destination == null
          ? const PluginMcpConnectorSetupUnavailable(
              reason: PluginMcpConnectorSetupUnavailableReason.nativeConfigurationRequired,
            )
          : PluginMcpConnectorExternalSetup(destination: destination);
    } on Object catch (error, stackTrace) {
      return PluginMcpConnectorSetupFailed(
        cause: error is Exception ? error : CodexMcpInventoryReadException(innerError: error),
        causeStackTrace: stackTrace,
      );
    }
  }

  /// Server authentication validates its target without fetching a connector catalog.
  Future<PluginMcpInventoryResult> readServers({required PluginMcpScope scope}) async {
    final String? threadId;
    switch (scope) {
      case PluginMcpProjectScope():
        return const PluginMcpInventoryUnavailable(
          reason: PluginMcpInventoryUnavailableReason.unsupportedScope,
          message: "Codex MCP inventory supports harness and existing thread scopes, not projects.",
        );
      case PluginMcpSessionScope(:final sessionId):
        threadId = sessionId;
      case PluginMcpHarnessScope():
        threadId = null;
    }
    final context = threadId == null ? "harness" : "thread $threadId";
    try {
      final servers = <CodexMcpServerStatusDto>[];
      String? cursor;
      do {
        final page = await _appServerApi.listMcpServersPage(threadId: threadId, cursor: cursor);
        servers.addAll(page.data);
        cursor = page.nextCursor;
      } while (cursor != null);
      for (final server in servers) {
        if (server.toolsError case final error?) {
          Log.w(
            "[codex] MCP tool discovery failed for ${server.name} in $context",
            StateError(error),
            StackTrace.current,
          );
        }
      }
      return _mapper.map(servers: servers, scope: scope);
    } on CodexMcpThreadNotLoadedException catch (error, stackTrace) {
      Log.w("[codex] MCP inventory requires a live thread in $context", error.innerError, stackTrace);
      return const PluginMcpInventoryUnavailable(
        reason: PluginMcpInventoryUnavailableReason.liveSessionRequired,
        message: "Open this Codex thread in a live session before inspecting its MCP servers.",
      );
    } on Object catch (error, stackTrace) {
      return PluginMcpInventoryReadFailed(
        cause: error is Exception ? error : CodexMcpInventoryReadException(innerError: error),
        causeStackTrace: stackTrace,
      );
    }
  }
}
