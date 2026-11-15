import "package:drift/drift.dart";

import "../database.dart";
import "../tables/side_chat_exchanges_table.dart";

part "side_chat_dao.g.dart";

@DriftAccessor(tables: [SideChatExchangesTable])
class SideChatDao({required AppDatabase database}) extends DatabaseAccessor<AppDatabase> with _$SideChatDaoMixin {
  this : super(database);

  Future<void> insertExchange({required SideChatExchangeDto row}) async {
    await into(sideChatExchangesTable).insert(row);
  }

  /// Every exchange of [sessionId], oldest answer first.
  Future<List<SideChatExchangeDto>> listForSession({required String sessionId}) {
    return (select(sideChatExchangesTable)
          ..where((row) => row.sessionId.equals(sessionId))
          ..orderBy([(row) => OrderingTerm.asc(row.answeredAt), (row) => OrderingTerm.asc(row.id)]))
        .get();
  }

  /// The exchanges of one side chat, oldest answer first.
  Future<List<SideChatExchangeDto>> listForSideChat({required String sessionId, required String sideChatId}) {
    return (select(sideChatExchangesTable)
          ..where((row) => row.sessionId.equals(sessionId) & row.sideChatId.equals(sideChatId))
          ..orderBy([(row) => OrderingTerm.asc(row.answeredAt), (row) => OrderingTerm.asc(row.id)]))
        .get();
  }
}
