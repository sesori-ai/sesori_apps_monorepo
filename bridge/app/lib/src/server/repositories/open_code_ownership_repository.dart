import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;
import 'package:sesori_shared/sesori_shared.dart';

import '../api/runtime_file_api.dart';
import '../models/open_code_ownership_record.dart';

class OpenCodeOwnershipRepository {
  OpenCodeOwnershipRepository({
    required RuntimeFileApi runtimeFileApi,
    required Clock clock,
  })  : _runtimeFileApi = runtimeFileApi,
        _clock = clock;

  final RuntimeFileApi _runtimeFileApi;
  final Clock _clock;

  Future<List<OpenCodeOwnershipRecord>> readAll() async {
    final records = await _loadRecords();
    return records.values.toList(growable: false);
  }

  Future<OpenCodeOwnershipRecord?> readByOwnerSessionId({required String ownerSessionId}) async {
    final records = await _loadRecords();
    return records[ownerSessionId];
  }

  Future<void> upsert({required OpenCodeOwnershipRecord record}) async {
    final records = await _loadRecords();
    records[record.ownerSessionId] = record;
    await _writeRecords(records: records);
  }

  Future<void> deleteByOwnerSessionId({required String ownerSessionId}) async {
    final records = await _loadRecords();
    final removedRecord = records.remove(ownerSessionId);
    if (removedRecord == null) {
      return;
    }

    if (records.isEmpty) {
      await _runtimeFileApi.deleteOwnershipFile();
      return;
    }

    await _writeRecords(records: records);
  }

  Future<Map<String, OpenCodeOwnershipRecord>> _loadRecords() async {
    final String? contents;
    try {
      contents = await _runtimeFileApi.readOwnershipFile();
    } on Object catch (error) {
      await _handleInvalidRuntimeFile(
        reason: 'unreadable OpenCode ownership runtime file',
        error: error,
      );
      return <String, OpenCodeOwnershipRecord>{};
    }

    if (contents == null || contents.trim().isEmpty) {
      return <String, OpenCodeOwnershipRecord>{};
    }

    try {
      final Map<String, dynamic> rootJson = jsonDecodeMap(contents);
      return <String, OpenCodeOwnershipRecord>{
        for (final MapEntry<String, dynamic> entry in rootJson.entries)
          entry.key: OpenCodeOwnershipRecord.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
      };
    } on Object catch (error) {
      await _handleInvalidRuntimeFile(
        reason: 'invalid OpenCode ownership runtime file',
        error: error,
      );
      return <String, OpenCodeOwnershipRecord>{};
    }
  }

  Future<void> _writeRecords({required Map<String, OpenCodeOwnershipRecord> records}) async {
    final payload = <String, dynamic>{
      for (final MapEntry<String, OpenCodeOwnershipRecord> entry in records.entries)
        entry.key: entry.value.toJson(),
    };
    await _runtimeFileApi.writeOwnershipFile(contents: jsonEncode(payload));
  }

  Future<void> _handleInvalidRuntimeFile({
    required String reason,
    required Object error,
  }) async {
    Log.w(
      '$reason at ${_runtimeFileApi.ownershipFilePath}; ignoring persisted ownership state and continuing fresh. Error: $error',
    );

    final String timestamp = _clock
        .now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');

    try {
      await _runtimeFileApi.renameOwnershipFile(
        fileName: 'opencode-processes.invalid.$timestamp.json',
      );
    } on Object catch (renameError) {
      Log.w(
        'Failed to rename invalid OpenCode ownership runtime file at ${_runtimeFileApi.ownershipFilePath}; continuing fresh without persisted ownership state. Error: $renameError',
      );
    }
  }
}
