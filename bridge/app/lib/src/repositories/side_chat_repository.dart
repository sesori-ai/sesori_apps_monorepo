import "dart:math";

import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/side_chat_dao.dart";
import "../api/database/database.dart";
import "random_hex_id.dart";

/// Stored side chats. A side chat exists only as its exchanges, which share a
/// side-chat id.
class SideChatRepository({required final SideChatDao _dao}) {
  static final Random _secureRandom = Random.secure();

  /// The side chats of [sessionId], newest first by their last answer, each
  /// with its exchanges oldest first.
  Future<SideChatListResponse> listForSession({required String sessionId}) async {
    final exchangesByChat = <String, List<SideChatExchange>>{};
    for (final row in await _dao.listForSession(sessionId: sessionId)) {
      (exchangesByChat[row.sideChatId] ??= []).add(_toExchange(row: row));
    }
    final sideChats = [
      for (final MapEntry(key: id, value: exchanges) in exchangesByChat.entries) SideChat(id: id, exchanges: exchanges),
    ]..sort((a, b) => b.exchanges.last.answeredAt.compareTo(a.exchanges.last.answeredAt));
    return SideChatListResponse(sideChats: sideChats);
  }

  /// The earlier exchanges of [sideChatId], oldest first, as plugin history;
  /// none when [sideChatId] is null because the ask starts a new chat.
  Future<List<PluginSideExchange>> historyFor({required String sessionId, required String? sideChatId}) async {
    if (sideChatId == null) return const [];
    final rows = await _dao.listForSideChat(sessionId: sessionId, sideChatId: sideChatId);
    return [for (final row in rows) PluginSideExchange(question: row.question, answer: row.answer)];
  }

  /// Stores one answered exchange, minting the side-chat id when [sideChatId]
  /// is null, and returns it in wire terms.
  Future<({String sideChatId, SideChatExchange exchange})> recordExchange({
    required String sessionId,
    required String? sideChatId,
    required String question,
    required String answer,
    required String? notice,
    required DateTime askedAt,
  }) async {
    final row = SideChatExchangeDto(
      id: generateRandomHexId(secureRandom: _secureRandom, prefix: "sqx_", byteLength: 16),
      sessionId: sessionId,
      sideChatId: sideChatId ?? generateRandomHexId(secureRandom: _secureRandom, prefix: "sqc_", byteLength: 16),
      question: question,
      answer: answer,
      answerNotice: notice,
      askedAt: askedAt.millisecondsSinceEpoch,
      answeredAt: clock.now().millisecondsSinceEpoch,
    );
    await _dao.insertExchange(row: row);
    return (sideChatId: row.sideChatId, exchange: _toExchange(row: row));
  }

  SideChatExchange _toExchange({required SideChatExchangeDto row}) => SideChatExchange(
    id: row.id,
    question: row.question,
    answer: row.answer,
    answerNotice: row.answerNotice,
    askedAt: row.askedAt,
    answeredAt: row.answeredAt,
  );
}
