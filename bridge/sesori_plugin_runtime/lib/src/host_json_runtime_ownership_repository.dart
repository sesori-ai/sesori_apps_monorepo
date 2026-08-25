import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "runtime_ownership_repository.dart";
import "runtime_record_mapper.dart";

class HostJsonRuntimeOwnershipRepository<R>({
  required final HostJsonStore _store,
  required final RuntimeRecordMapper<R> _mapper,
  required final String _fileName,
  required final ServerClock _clock,
}) implements RuntimeOwnershipRepository<R> {
  @override
  Future<List<R>> readAll() async {
    final records = await _loadRecordsFromRead();
    return records.values.toList(growable: false);
  }

  @override
  Future<R?> readByOwnerSessionId({required String ownerSessionId}) async {
    final records = await _loadRecordsFromRead();
    return records[ownerSessionId];
  }

  @override
  Future<void> upsert({required R record}) async {
    await _store.update(
      name: _fileName,
      transform: (current) async {
        final parsed = _parseRecords(contents: current);
        if (parsed.invalidError case final invalidError?) {
          await _handleInvalidRuntimeFile(reason: "invalid runtime ownership file", error: invalidError);
        }
        parsed.records[_mapper.ownerSessionIdOf(record: record)] = record;
        return jsonEncode(_recordsToJson(records: parsed.records));
      },
    );
  }

  @override
  Future<void> deleteByOwnerSessionId({required String ownerSessionId}) async {
    await _store.update(
      name: _fileName,
      transform: (current) async {
        final parsed = _parseRecords(contents: current);
        if (parsed.invalidError case final invalidError?) {
          await _handleInvalidRuntimeFile(reason: "invalid runtime ownership file", error: invalidError);
        }
        final removedRecord = parsed.records.remove(ownerSessionId);
        if (removedRecord == null) {
          // Nothing to delete: leave a valid file byte-for-byte untouched
          // (legacy early-returns without writing). If the contents were just
          // quarantined, returning null keeps the original name absent instead
          // of resurrecting the corrupt bytes.
          return parsed.invalidError != null ? null : current;
        }
        if (parsed.records.isEmpty) {
          return null;
        }
        return jsonEncode(_recordsToJson(records: parsed.records));
      },
    );
  }

  Future<Map<String, R>> _loadRecordsFromRead() async {
    final String? contents;
    try {
      contents = await _store.read(name: _fileName);
    } on Object catch (error) {
      await _quarantineIfStillInvalid(reason: "unreadable runtime ownership file", error: error);
      return <String, R>{};
    }
    final parsed = _parseRecords(contents: contents);
    if (parsed.invalidError case final invalidError?) {
      await _quarantineIfStillInvalid(reason: "invalid runtime ownership file", error: invalidError);
      return <String, R>{};
    }
    return parsed.records;
  }

  // ignore: no_slop_linter/prefer_specific_type, parse failures retain their opaque original error
  ({Map<String, R> records, Object? invalidError}) _parseRecords({required String? contents}) {
    if (contents == null || contents.trim().isEmpty) {
      return (records: <String, R>{}, invalidError: null);
    }

    try {
      // ignore: no_slop_linter/prefer_specific_type, JSON decoding produces dynamic values at this boundary.
      final dynamic decoded = jsonDecode(contents);
      // ignore: no_slop_linter/prefer_specific_type, JSON objects contain heterogeneous values
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException("Runtime ownership root must be an object");
      }
      final records = <String, R>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        // ignore: no_slop_linter/prefer_specific_type, JSON objects contain heterogeneous values
        if (value is! Map<String, dynamic>) {
          throw const FormatException("Runtime ownership record must be an object");
        }
        records[entry.key] = _mapper.fromJson(json: value);
      }
      return (records: records, invalidError: null);
    } on Object catch (error) {
      return (records: <String, R>{}, invalidError: error);
    }
  }

  /// Quarantines the ownership file only if it is still invalid when observed
  /// under the store's update lock. A snapshot that failed to parse on the
  /// unlocked read path must not rename the file directly: a concurrent
  /// locked mutation may have repaired it in between, and renaming then would
  /// quarantine a freshly written valid file.
  Future<void> _quarantineIfStillInvalid({required String reason, required Object error}) async {
    try {
      await _store.update(
        name: _fileName,
        transform: (current) async {
          if (current == null || current.trim().isEmpty) {
            return current;
          }
          final recheck = _parseRecords(contents: current);
          if (recheck.invalidError case final invalidError?) {
            await _handleInvalidRuntimeFile(reason: reason, error: invalidError);
            return null;
          }
          return current;
        },
      );
    } on Object catch (updateError, stackTrace) {
      Log.w(
        "Could not revalidate runtime ownership file at $_fileName before quarantine; "
        "continuing fresh without persisted ownership state. Original error: ${error.toString()}",
        updateError,
        stackTrace,
      );
    }
  }

  // ignore: no_slop_linter/prefer_specific_type, JSON encoding requires dynamic values at this boundary.
  Map<String, dynamic> _recordsToJson({required Map<String, R> records}) {
    // ignore: no_slop_linter/prefer_specific_type, JSON encoding requires dynamic values at this boundary.
    return <String, dynamic>{
      for (final MapEntry<String, R> entry in records.entries) entry.key: _mapper.toJson(record: entry.value),
    };
  }

  Future<void> _handleInvalidRuntimeFile({required String reason, required Object error}) async {
    Log.w("$reason at $_fileName; ignoring persisted ownership state and continuing fresh", error);

    final timestamp = _clock.now().toUtc().toIso8601String().replaceAll(":", "-").replaceAll(".", "-");
    final quarantinedName = "${_fileNameBase()}.invalid.$timestamp.json";

    try {
      await _store.quarantine(name: _fileName, quarantinedName: quarantinedName);
    } on Object catch (renameError, stackTrace) {
      Log.w(
        "Failed to rename invalid runtime ownership file at $_fileName; continuing fresh without persisted ownership state",
        renameError,
        stackTrace,
      );
    }
  }

  String _fileNameBase() {
    if (_fileName.endsWith(".json")) {
      return _fileName.substring(0, _fileName.length - ".json".length);
    }
    return _fileName;
  }
}
