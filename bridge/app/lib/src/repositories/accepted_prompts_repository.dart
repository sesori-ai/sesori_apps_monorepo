import "package:clock/clock.dart";

import "../api/database/daos/accepted_prompts_dao.dart";
import "../api/database/database.dart";

class AcceptedPromptsRepository({required final AcceptedPromptsDao _dao}) {
  /// Outlasts any realistic lost-response retry, such as a phone suspended
  /// over a weekend resending on resume, while keeping the table small.
  static const _retention = Duration(days: 30);

  Future<bool> isAccepted({required String sessionId, required String promptId}) {
    return _dao.hasRow(sessionId: sessionId, promptId: promptId);
  }

  Future<void> recordAccepted({required String sessionId, required String promptId}) async {
    final now = clock.now();
    await _dao.insertRow(
      row: AcceptedPromptsTableData(
        sessionId: sessionId,
        promptId: promptId,
        acceptedAt: now.millisecondsSinceEpoch,
      ),
    );
    await _dao.deleteAcceptedBefore(cutoff: now.subtract(_retention).millisecondsSinceEpoch);
  }
}
