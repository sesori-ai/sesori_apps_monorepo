import "package:sesori_shared/sesori_shared.dart" show Message, MessagePart;

sealed class CommandTimelineMutation {
  const CommandTimelineMutation();
}

class CommandTimelineEnvelopeUpdated extends CommandTimelineMutation {
  final Message info;

  const CommandTimelineEnvelopeUpdated({required this.info});
}

class CommandTimelineMessageRemoved extends CommandTimelineMutation {
  final String sessionId;
  final String messageId;

  const CommandTimelineMessageRemoved({required this.sessionId, required this.messageId});
}

class CommandTimelinePartUpdated extends CommandTimelineMutation {
  final MessagePart part;

  const CommandTimelinePartUpdated({required this.part});
}

class CommandTimelinePartDelta extends CommandTimelineMutation {
  final String sessionId;
  final String messageId;
  final String partId;
  final String field;
  final String delta;

  const CommandTimelinePartDelta({
    required this.sessionId,
    required this.messageId,
    required this.partId,
    required this.field,
    required this.delta,
  });
}

class CommandTimelinePartRemoved extends CommandTimelineMutation {
  final String sessionId;
  final String messageId;
  final String partId;

  const CommandTimelinePartRemoved({
    required this.sessionId,
    required this.messageId,
    required this.partId,
  });
}
