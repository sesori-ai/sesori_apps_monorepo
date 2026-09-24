import "dart:convert";

import "../../api/database/database.dart";
import "../models/session_continuation_record.dart";

class const SessionContinuationMapper() {
  SessionContinuationRecord fromDto({required SessionContinuationDto row}) => SessionContinuationRecord(
    sessionId: row.sessionId,
    enabled: row.enabled,
    outcome: SessionContinuationOutcome.fromJson(jsonDecode(row.outcomeJson) as Map<String, dynamic>),
  );

  SessionContinuationDto toDto({required SessionContinuationRecord record}) => SessionContinuationDto(
    sessionId: record.sessionId,
    enabled: record.enabled,
    outcomeJson: jsonEncode(record.outcome.toJson()),
  );
}
