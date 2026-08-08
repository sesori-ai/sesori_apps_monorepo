// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_history_dao.dart';

// ignore_for_file: type=lint
mixin _$ChatHistoryDaoMixin on DatabaseAccessor<ChatHistoryDatabase> {
  $HistoryMessagesTableTable get historyMessagesTable =>
      attachedDatabase.historyMessagesTable;
  $HistoryPartsTableTable get historyPartsTable =>
      attachedDatabase.historyPartsTable;
  $HistorySyncStateTableTable get historySyncStateTable =>
      attachedDatabase.historySyncStateTable;
  ChatHistoryDaoManager get managers => ChatHistoryDaoManager(this);
}

class ChatHistoryDaoManager {
  final _$ChatHistoryDaoMixin _db;
  ChatHistoryDaoManager(this._db);
  $$HistoryMessagesTableTableTableManager get historyMessagesTable =>
      $$HistoryMessagesTableTableTableManager(
        _db.attachedDatabase,
        _db.historyMessagesTable,
      );
  $$HistoryPartsTableTableTableManager get historyPartsTable =>
      $$HistoryPartsTableTableTableManager(
        _db.attachedDatabase,
        _db.historyPartsTable,
      );
  $$HistorySyncStateTableTableTableManager get historySyncStateTable =>
      $$HistorySyncStateTableTableTableManager(
        _db.attachedDatabase,
        _db.historySyncStateTable,
      );
}
