import "../../api/database/database.dart";
import "../models/session_interruption_record.dart";

class const SessionInterruptionMapper() {
  SessionInterruptionRecord fromDto({required SessionInterruptionDto row}) => SessionInterruptionRecord(
    sessionId: row.sessionId,
    afterMessageId: row.afterMessageId,
    acknowledged: row.acknowledged,
  );

  SessionInterruptionDto toDto({required SessionInterruptionRecord record}) => SessionInterruptionDto(
    sessionId: record.sessionId,
    afterMessageId: record.afterMessageId,
    acknowledged: record.acknowledged,
  );
}
