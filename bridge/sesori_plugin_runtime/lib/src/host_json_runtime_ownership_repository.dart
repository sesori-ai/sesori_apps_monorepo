import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "runtime_ownership_repository.dart";
import "runtime_record_mapper.dart";

class HostJsonRuntimeOwnershipRepository<R> implements RuntimeOwnershipRepository<R> {
  HostJsonRuntimeOwnershipRepository({
    required HostJsonStore store,
    required RuntimeRecordMapper<R> mapper,
    required String fileName,
    required ServerClock clock,
  }) : _store = store,
       _mapper = mapper,
       _fileName = fileName,
       _clock = clock;

  final HostJsonStore _store;
  final RuntimeRecordMapper<R> _mapper;
  final String _fileName;
  final ServerClock _clock;

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
        if (parsed.invalidError != null) {
          await _handleInvalidRuntimeFile(reason: "invalid runtime ownership file", error: parsed.invalidError!);
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
        if (parsed.invalidError != null) {
          await _handleInvalidRuntimeFile(reason: "invalid runtime ownership file", error: parsed.invalidError!);
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
    if (parsed.invalidError != null) {
      await _quarantineIfStillInvalid(reason: "invalid runtime ownership file", error: parsed.invalidError!);
      return <String, R>{};
    }
    return parsed.records;
  }

  ({Map<String, R> records, Object? invalidError}) _parseRecords({required String? contents}) {
    if (contents == null || contents.trim().isEmpty) {
      return (records: <String, R>{}, invalidError: null);
    }

    try {
      final decoded = jsonDecode(contents);
      if (decoded is! Map) {
        throw const FormatException("Runtime ownership root must be an object");
      }
      final rootJson = Map<String, dynamic>.from(decoded);
      return (
        records: <String, R>{
          for (final MapEntry<String, dynamic> entry in rootJson.entries)
            entry.key: _mapper.fromJson(json: Map<String, dynamic>.from(entry.value as Map)),
        },
        invalidError: null,
      );
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
          if (recheck.invalidError == null) {
            return current;
          }
          await _handleInvalidRuntimeFile(reason: reason, error: recheck.invalidError!);
          return null;
        },
      );
    } on Object catch (updateError) {
      Log.w(
        "Could not revalidate runtime ownership file at $_fileName before quarantine; "
        "continuing fresh without persisted ownership state. Error: $updateError (original: $error)",
      );
    }
  }

  Map<String, dynamic> _recordsToJson({required Map<String, R> records}) {
    return <String, dynamic>{
      for (final MapEntry<String, R> entry in records.entries) entry.key: _mapper.toJson(record: entry.value),
    };
  }

  Future<void> _handleInvalidRuntimeFile({required String reason, required Object error}) async {
    Log.w("$reason at $_fileName; ignoring persisted ownership state and continuing fresh. Error: $error");

    final timestamp = _clock.now().toUtc().toIso8601String().replaceAll(":", "-").replaceAll(".", "-");
    final quarantinedName = "${_fileNameBase()}.invalid.$timestamp.json";

    try {
      await _store.quarantine(name: _fileName, quarantinedName: quarantinedName);
    } on Object catch (renameError) {
      Log.w(
        "Failed to rename invalid runtime ownership file at $_fileName; continuing fresh without persisted ownership state. Error: $renameError",
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
