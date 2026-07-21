import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginSession, PluginSessionTime;

import "../api/codex_app_server_api.dart";
import "../api/models/codex_thread_dto.dart";
import "models/codex_thread_record.dart";

/// Layer-2 normalization and domain mapping for Codex app-server threads.
class CodexThreadRepository {
  CodexThreadRepository({required CodexAppServerApi appServerApi}) : _appServerApi = appServerApi;

  final CodexAppServerApi _appServerApi;

  Future<CodexThreadRecord> startThread({
    required String cwd,
    required String? model,
    required String? modelProvider,
  }) async {
    final dto = await _appServerApi.startThread(
      cwd: cwd,
      model: model,
      modelProvider: modelProvider,
    );
    return _mapRequired(dto: dto, operation: "thread/start");
  }

  Future<CodexThreadRecord> resumeThread({required String threadId}) async {
    final dto = await _appServerApi.resumeThread(threadId: threadId);
    return _mapRequired(dto: dto, operation: "thread/resume");
  }

  CodexThreadRecord? mapStartedNotification({
    required CodexThreadEnvelopeDto dto,
  }) => _map(dto: dto);

  CodexThreadRecord? decodeStartedNotificationParams({
    required Map<String, dynamic> params,
  }) {
    final dto = _appServerApi.decodeThreadStartedParams(params: params);
    return dto == null ? null : mapStartedNotification(dto: dto);
  }

  PluginSession toPluginSession({
    required CodexThreadRecord record,
    required String fallbackDirectory,
    required String? parentSessionId,
  }) {
    final directory = record.directory ?? normalizeProjectDirectory(directory: fallbackDirectory);
    final created = record.createdAt;
    final updated = record.updatedAt;
    return PluginSession(
      branchName: record.branch,
      id: record.id,
      projectID: directory,
      directory: directory,
      parentID: parentSessionId,
      title: record.name,
      time: created == null || updated == null
          ? null
          : PluginSessionTime(
              created: created,
              updated: updated,
              archived: null,
            ),
    );
  }

  CodexThreadRecord _mapRequired({
    required CodexThreadEnvelopeDto dto,
    required String operation,
  }) {
    final record = _map(dto: dto);
    if (record == null) {
      throw StateError("$operation response missing thread.id");
    }
    return record;
  }

  CodexThreadRecord? _map({required CodexThreadEnvelopeDto dto}) {
    final thread = dto.thread;
    final id = _usefulText(thread?.id);
    if (thread == null || id == null) return null;
    final cwd = _usefulText(thread.cwd) ?? _usefulText(dto.cwd);
    return CodexThreadRecord(
      id: id,
      name: thread.name,
      directory: cwd == null ? null : normalizeProjectDirectory(directory: cwd),
      createdAt: _milliseconds(thread.createdAt),
      updatedAt: _milliseconds(thread.updatedAt),
      model: _usefulText(dto.model),
      modelProvider: _usefulText(thread.modelProvider) ?? _usefulText(dto.modelProvider),
      branch: _usefulText(thread.gitInfo?.branch),
    );
  }

  int? _milliseconds(num? seconds) => seconds == null ? null : (seconds * 1000).round();

  String? _usefulText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
