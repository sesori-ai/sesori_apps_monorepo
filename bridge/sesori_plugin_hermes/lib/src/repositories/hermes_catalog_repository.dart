import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;

import "../api/hermes_acp_api.dart";
import "../models/hermes_model_catalog.dart";
import "../models/hermes_model_state_dto.dart";

/// Maps Hermes's model state and owns one disposable discovery transaction.
class HermesCatalogRepository({required final HermesAcpApi _api}) {
  /// Hermes Agent 0.20.4 has no pre-session route that lists agents, models,
  /// or variants, so discovery creates and then deletes a disposable session.
  Future<HermesModelCatalog> discoverCatalog({
    required String cwd,
    required Duration timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    String? sessionId;
    HermesModelCatalog? catalog;
    Object? discoveryError;
    StackTrace? discoveryStack;

    try {
      await _api.openScratch(
        cwd: cwd,
        timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
      );
      final result = await _api.newScratchSession(
        cwd: cwd,
        timeout: _remaining(timeout: timeout, stopwatch: stopwatch),
      );
      sessionId = result.sessionId;
      if (sessionId.isEmpty) throw StateError("Hermes catalog session/new omitted sessionId");
      catalog = mapSessionResult(result: result);
      if (catalog == null || catalog.models.isEmpty) {
        throw StateError("Hermes catalog session/new omitted model state");
      }
    } on Object catch (error, stackTrace) {
      discoveryError = error;
      discoveryStack = stackTrace;
    }

    Object? cleanupError;
    StackTrace? cleanupStack;
    var processExited = false;
    try {
      await _api.settleScratch(
        timeout: _cleanupTimeout(timeout: timeout, stopwatch: stopwatch),
      );
      processExited = true;
      if (sessionId != null && sessionId.isNotEmpty) {
        await _api.deletePersistedSession(
          sessionId: sessionId,
          timeout: _cleanupTimeout(timeout: timeout, stopwatch: stopwatch),
        );
      }
    } on Object catch (error, stackTrace) {
      cleanupError = PluginOperationException(
        "hermes catalog cleanup",
        message: processExited
            ? "Could not delete Hermes discovery session $sessionId"
            : "Hermes discovery process did not exit; session $sessionId was not deleted",
        cause: error,
      );
      cleanupStack = stackTrace;
    }

    if (discoveryError != null) {
      if (cleanupError != null) {
        Log.w("[hermes] cleanup also failed after model discovery failed", cleanupError, cleanupStack);
      }
      Error.throwWithStackTrace(discoveryError, discoveryStack!);
    }
    if (cleanupError != null) {
      Error.throwWithStackTrace(cleanupError, cleanupStack!);
    }
    return catalog!;
  }

  Future<void> setModel({
    required AcpStdioClient liveClient,
    required String sessionId,
    required String modelId,
    required Duration timeout,
  }) => _api.setModel(
    liveClient: liveClient,
    sessionId: sessionId,
    modelId: modelId,
    timeout: timeout,
  );

  HermesModelCatalog? mapSessionResult({required AcpNewSessionResult result}) {
    final rawModels = result.raw["models"];
    if (rawModels is! Map) return null;
    final state = HermesSessionModelStateDto.fromJson(rawModels.cast<String, dynamic>());
    final models = <HermesCatalogModel>[];
    for (final entry in state.availableModels) {
      final value = entry.modelId?.trim();
      if (value == null || value.isEmpty) continue;
      final split = _splitModelValue(value);
      final display = _splitDisplayName(entry.name);
      models.add(
        HermesCatalogModel(
          value: value,
          providerId: split.providerId,
          providerName: display.providerName ?? split.providerId,
          modelId: split.modelId,
          name: display.modelName ?? split.modelId,
        ),
      );
    }
    final current = state.currentModelId?.trim();
    return HermesModelCatalog(
      models: models,
      currentModelValue: current == null || current.isEmpty ? null : current,
    );
  }

  Future<void> dispose() => _api.dispose();

  ({String providerId, String modelId}) _splitModelValue(String value) {
    if (value.startsWith("custom:")) {
      final separator = value.indexOf(":", "custom:".length);
      if (separator > "custom:".length && separator < value.length - 1) {
        return (
          providerId: value.substring(0, separator),
          modelId: value.substring(separator + 1),
        );
      }
    }
    final separator = value.indexOf(":");
    if (separator <= 0 || separator == value.length - 1) {
      return (providerId: "hermes", modelId: value);
    }
    return (
      providerId: value.substring(0, separator),
      modelId: value.substring(separator + 1),
    );
  }

  ({String? providerName, String? modelName}) _splitDisplayName(String? value) {
    final displayValue = value?.trim();
    if (displayValue == null || displayValue.isEmpty) {
      return (providerName: null, modelName: null);
    }
    const separatorToken = " \u00b7 ";
    final separator = displayValue.indexOf(separatorToken);
    if (separator <= 0 || separator == displayValue.length - separatorToken.length) {
      return (providerName: null, modelName: displayValue);
    }
    return (
      providerName: displayValue.substring(0, separator).trim(),
      modelName: displayValue.substring(separator + separatorToken.length).trim(),
    );
  }

  Duration _remaining({required Duration timeout, required Stopwatch stopwatch}) {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("Hermes model discovery exceeded $timeout");
    }
    return remaining;
  }

  Duration _cleanupTimeout({required Duration timeout, required Stopwatch stopwatch}) {
    final remaining = timeout - stopwatch.elapsed;
    return remaining > const Duration(seconds: 5) ? remaining : const Duration(seconds: 5);
  }
}
