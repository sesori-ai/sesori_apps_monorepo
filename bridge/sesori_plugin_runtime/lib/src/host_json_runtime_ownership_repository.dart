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
        final loaded = await _loadRecordsFromContents(contents: current);
        loaded.records[_mapper.ownerSessionIdOf(record: record)] = record;
        return jsonEncode(_recordsToJson(records: loaded.records));
      },
    );
  }

  @override
  Future<void> deleteByOwnerSessionId({required String ownerSessionId}) async {
    await _store.update(
      name: _fileName,
      transform: (current) async {
        final loaded = await _loadRecordsFromContents(contents: current);
        final removedRecord = loaded.records.remove(ownerSessionId);
        if (removedRecord == null) {
          // Nothing to delete: leave a valid file byte-for-byte untouched
          // (legacy early-returns without writing). If the contents were just
          // quarantined, returning null keeps the original name absent instead
          // of resurrecting the corrupt bytes.
          return loaded.wasInvalid ? null : current;
        }
        if (loaded.records.isEmpty) {
          return null;
        }
        return jsonEncode(_recordsToJson(records: loaded.records));
      },
    );
  }

  Future<Map<String, R>> _loadRecordsFromRead() async {
    final String? contents;
    try {
      contents = await _store.read(name: _fileName);
    } on Object catch (error) {
      await _handleInvalidRuntimeFile(reason: "unreadable runtime ownership file", error: error);
      return <String, R>{};
    }
    final loaded = await _loadRecordsFromContents(contents: contents);
    return loaded.records;
  }

  Future<({Map<String, R> records, bool wasInvalid})> _loadRecordsFromContents({required String? contents}) async {
    if (contents == null || contents.trim().isEmpty) {
      return (records: <String, R>{}, wasInvalid: false);
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
        wasInvalid: false,
      );
    } on Object catch (error) {
      await _handleInvalidRuntimeFile(reason: "invalid runtime ownership file", error: error);
      return (records: <String, R>{}, wasInvalid: true);
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
