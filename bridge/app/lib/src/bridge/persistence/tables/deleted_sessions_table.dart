import "package:drift/drift.dart" hide JsonKey;
import "package:freezed_annotation/freezed_annotation.dart";

import "../database.dart";

part "deleted_sessions_table.freezed.dart";

/// Tombstones for deleted derive-plugin sessions.
///
/// A derived backend (ACP/Cursor) may not support deleting sessions at all,
/// so a session the user deleted keeps coming back from the backend's
/// enumeration forever. The tombstone filters it out of every derived
/// enumeration path after its `sessions_table` row is removed. Rows are
/// permanent — session ids are UUIDs and never reused — and bounded by
/// actual deletions.
@UseRowClass(DeletedSessionDto)
class DeletedSessionsTable extends Table {
  @override
  String get tableName => "deleted_sessions_table";

  /// Current owner of this durable local entity. Local mode has one owner;
  /// carrying it in the key keeps future identity scoping possible.
  TextColumn get ownerIdentity => text().withDefault(const Constant("local"))();

  TextColumn get sessionId => text()();

  /// The id of the plugin that owned the session. Scoping keeps one plugin's
  /// tombstones from ever touching another plugin's sessions.
  TextColumn get pluginId => text()();

  IntColumn get deletedAt => integer()();

  @override
  bool get withoutRowId => true;

  @override
  Set<Column>? get primaryKey => {ownerIdentity, pluginId, sessionId};
}

@freezed
sealed class DeletedSessionDto with _$DeletedSessionDto, $DeletedSessionsTableTableToColumns {
  const factory DeletedSessionDto({
    required String ownerIdentity,
    required String sessionId,
    required String pluginId,
    required int deletedAt,
  }) = _DeletedSessionDto;

  const DeletedSessionDto._();
}
