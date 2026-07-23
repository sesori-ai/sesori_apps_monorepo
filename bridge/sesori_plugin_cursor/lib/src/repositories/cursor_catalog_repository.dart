import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../api/cursor_catalog_probe_api.dart";
import "../models/cursor_catalog_models.dart";
import "mappers/cursor_catalog_mapper.dart";

/// Layer-2 aggregation and mapping for Cursor catalog discovery.
class CursorCatalogRepository {
  CursorCatalogRepository({
    required CursorCatalogProbeApi api,
    required String launchScope,
  }) : _api = api,
       _launchScope = normalizeProjectDirectory(directory: launchScope);

  final CursorCatalogProbeApi _api;
  final String _launchScope;

  Future<bool> open({required Duration timeout}) async {
    final result = await _api.open(timeout: timeout);
    final capabilities = result.agentCapabilities;
    return capabilities.listSessions && capabilities.loadSession;
  }

  /// Returns null only when this Cursor build does not expose model discovery.
  Future<CursorCatalogBootstrapSnapshot?> loadAvailableCatalog({required Duration timeout}) async {
    try {
      final result = await _api.listAvailableModels(timeout: timeout);
      return CursorCatalogMapper.mapAvailableModels(result: result);
    } on AcpRpcException catch (error) {
      if (error.code == -32601) return null;
      rethrow;
    }
  }

  /// Unions unfiltered, launch, and requested-scope enumeration results.
  Future<CursorCatalogCandidateListResult> listCandidates({
    required String scope,
    required Duration timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final normalizedScope = normalizeProjectDirectory(directory: scope);
    final candidatesById = <String, CursorCatalogCandidate>{};
    final unfilteredFallbackCandidates = <String>{};
    var exhaustive = true;
    final scopes = <String?>[
      null,
      _launchScope,
      if (normalizedScope != _launchScope) normalizedScope,
    ];

    for (final scanScope in scopes) {
      try {
        final sessions = await _api.listSessions(
          cwd: scanScope,
          timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
        );
        for (final session in sessions) {
          final sessionId = session.sessionId.trim();
          if (sessionId.isEmpty) continue;
          final rawCwd = session.cwd;
          final hasCwd = rawCwd != null && rawCwd.trim().isNotEmpty;
          final fallbackScope = scanScope ?? _launchScope;
          final cwd = !hasCwd ? fallbackScope : normalizeProjectDirectory(directory: rawCwd);
          final previous = candidatesById[sessionId];
          final replaceFallbackCwd =
              previous == null || (unfilteredFallbackCandidates.contains(sessionId) && (hasCwd || scanScope != null));
          final previousUpdatedAtMs = previous?.updatedAtMs;
          final updatedAtMs = previousUpdatedAtMs == null
              ? session.updatedAtMs
              : session.updatedAtMs == null || previousUpdatedAtMs >= session.updatedAtMs!
              ? previousUpdatedAtMs
              : session.updatedAtMs;
          candidatesById[sessionId] = CursorCatalogCandidate(
            sessionId: sessionId,
            cwd: replaceFallbackCwd ? cwd : previous.cwd,
            updatedAtMs: updatedAtMs,
          );
          if (scanScope == null && !hasCwd && previous == null) {
            unfilteredFallbackCandidates.add(sessionId);
          } else if (replaceFallbackCwd) {
            unfilteredFallbackCandidates.remove(sessionId);
          }
        }
      } on AcpRpcException catch (error, stack) {
        if (scanScope == null && (error.code == -32601 || error.code == -32602)) {
          Log.d(
            "[cursor] unfiltered catalog session/list is unsupported "
            "(code=${error.code})",
          );
          continue;
        }
        exhaustive = false;
        Log.w(
          "[cursor] catalog session/list failed (scope=${scanScope ?? "all"})",
          error,
          stack,
        );
      } on Object catch (error, stack) {
        exhaustive = false;
        Log.w(
          "[cursor] catalog session/list failed (scope=${scanScope ?? "all"})",
          error,
          stack,
        );
      }
    }

    return CursorCatalogCandidateListResult(
      candidates: [
        for (final entry in candidatesById.entries)
          if (!unfilteredFallbackCandidates.contains(entry.key)) entry.value,
      ],
      exhaustive: exhaustive,
    );
  }

  Future<CursorCatalogSnapshot> loadCandidate({
    required CursorCatalogCandidate candidate,
    required Duration timeout,
  }) async {
    final result = await _api.loadSession(
      sessionId: candidate.sessionId,
      cwd: candidate.cwd,
      timeout: timeout,
    );
    return mapSessionResult(result: result);
  }

  CursorCatalogSnapshot mapSessionResult({required AcpNewSessionResult result}) {
    return CursorCatalogMapper.mapSession(result: result);
  }

  Future<void> reset() => _api.reset();

  Future<void> dispose() => _api.dispose();

  Duration _remaining({required Duration timeout, required Stopwatch stopwatch}) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("Cursor catalog enumeration exceeded its deadline");
    }
    return remaining;
  }
}
