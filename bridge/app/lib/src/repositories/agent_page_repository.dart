import "dart:async";
import "dart:convert";
import "dart:math";

import "package:clock/clock.dart";
import "package:sesori_shared/sesori_shared.dart" show PageSection, PendingPage, jsonDecodeMap;

import "../api/database/daos/agent_pages_dao.dart";
import "../api/database/database.dart";
import "../api/database/tables/agent_pages_table.dart";
import "models/agent_page.dart";
import "random_hex_id.dart";

/// The pages agents sent the user. Pages persist, so a bridge restart keeps
/// the pending ones and an answered page can be reopened. Request ids are
/// random, so a stale id can never reach a newer page.
class AgentPageRepository({required final AgentPagesDao _dao}) {
  static final Random _secureRandom = Random.secure();

  final StreamController<AgentPageEvent> _events = StreamController.broadcast();

  /// Every page asked and settled.
  Stream<AgentPageEvent> get events => _events.stream;

  /// Stores a new pending page from [sessionId] and returns it. The session
  /// row must exist.
  Future<PendingPage> add({
    required String sessionId,
    required String? displaySessionId,
    required String title,
    required String? intro,
    required List<PageSection> sections,
  }) async {
    final page = PendingPage(
      id: generateRandomHexId(secureRandom: _secureRandom, prefix: "sesori-page-", byteLength: 16),
      sessionId: sessionId,
      displaySessionId: displaySessionId,
      title: title,
      intro: intro,
      sections: sections,
    );
    await _dao.insertPage(
      row: AgentPageDto(
        id: page.id,
        sessionId: sessionId,
        rootSessionId: displaySessionId ?? sessionId,
        pageJson: page,
        status: AgentPageStatus.pending,
        outcomeJson: null,
        createdAt: clock.now().millisecondsSinceEpoch,
        settledAt: null,
      ),
    );
    _emit(AgentPageAsked(page: page));
    return page;
  }

  /// The pending pages to show on [sessionId]'s screen: its own, and those of
  /// sessions surfaced under it, oldest first.
  Future<List<PendingPage>> pendingPages({required String sessionId}) async {
    return [for (final row in await _dao.listPending(sessionId: sessionId)) row.pageJson];
  }

  /// The page [id] names, pending or settled; null when there is none.
  Future<StoredAgentPage?> find({required String id}) async {
    final row = await _dao.getPage(id: id);
    if (row == null) return null;
    return StoredAgentPage(
      page: row.pageJson,
      outcome: switch (row.outcomeJson) {
        final json? => AgentPageOutcome.fromJson(jsonDecodeMap(json)),
        null => null,
      },
    );
  }

  /// Settles the pending page [id] with [outcome] and returns it. Null when
  /// the page is missing or already settled, so of concurrent settles only
  /// the first wins and announces the outcome.
  Future<PendingPage?> settle({required String id, required AgentPageOutcome outcome}) async {
    final row = await _dao.settlePending(
      id: id,
      status: switch (outcome) {
        AgentPageAnswered() => AgentPageStatus.answered,
        AgentPageDismissed() => AgentPageStatus.dismissed,
      },
      outcomeJson: jsonEncode(outcome.toJson()),
      settledAt: clock.now().millisecondsSinceEpoch,
    );
    if (row == null) return null;
    _emit(AgentPageSettled(page: row.pageJson, outcome: outcome));
    return row.pageJson;
  }

  /// The root sessions with a pending page.
  Future<Set<String>> awaitingRootSessionIds() => _dao.pendingRootSessionIds();

  Future<void> dispose() => _events.close();

  void _emit(AgentPageEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
