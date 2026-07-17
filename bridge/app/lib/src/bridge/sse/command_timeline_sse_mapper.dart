import "package:sesori_shared/sesori_shared.dart";

import "../services/command_timeline_mutation.dart";

class CommandTimelineSseMapper {
  const CommandTimelineSseMapper();

  SesoriSseEvent map(CommandTimelineMutation mutation) {
    return switch (mutation) {
      CommandTimelineEnvelopeUpdated(:final info) => SesoriSseEvent.messageUpdated(info: info),
      CommandTimelineMessageRemoved(:final sessionId, :final messageId) => SesoriSseEvent.messageRemoved(
        sessionID: sessionId,
        messageID: messageId,
      ),
      CommandTimelinePartUpdated(:final part) => SesoriSseEvent.messagePartUpdated(part: part),
      CommandTimelinePartDelta(:final sessionId, :final messageId, :final partId, :final field, :final delta) =>
        SesoriSseEvent.messagePartDelta(
          sessionID: sessionId,
          messageID: messageId,
          partID: partId,
          field: field,
          delta: delta,
        ),
      CommandTimelinePartRemoved(:final sessionId, :final messageId, :final partId) =>
        SesoriSseEvent.messagePartRemoved(
          sessionID: sessionId,
          messageID: messageId,
          partID: partId,
        ),
    };
  }

  List<SesoriSseEvent> mapAll(Iterable<CommandTimelineMutation> mutations) {
    return List.unmodifiable(mutations.map(map));
  }
}
