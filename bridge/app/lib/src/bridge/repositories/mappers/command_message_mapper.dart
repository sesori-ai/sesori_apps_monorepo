import "package:sesori_shared/sesori_shared.dart"
    show CommandMessageInfo, CommandOrigin, Message, MessagePart, MessagePartType, MessageTime, MessageWithParts;

class CommandMessageMapper {
  const CommandMessageMapper();

  MessageWithParts map({
    required String messageId,
    required String sessionId,
    required String name,
    required String? arguments,
    required CommandOrigin origin,
    required MessageTime? time,
    required Iterable<MessagePart> resultParts,
  }) {
    final fallbackPartId = "$messageId:fallback";
    final displayPartId = "$messageId:display";
    final mappedResults = [
      for (final part in resultParts)
        mapResultPart(
          part: part,
          messageId: messageId,
          sessionId: sessionId,
        ),
    ];
    final displayResult = mappedResults.where((part) => part.id == displayPartId).lastOrNull;
    return MessageWithParts(
      info: Message.user(
        id: messageId,
        sessionID: sessionId,
        agent: null,
        time: time,
        command: CommandMessageInfo(
          name: name,
          arguments: arguments,
          origin: origin,
          displayPartID: displayPartId,
        ),
      ),
      parts: [
        _textPart(
          id: fallbackPartId,
          sessionId: sessionId,
          messageId: messageId,
          text: _fallbackLine(name: name, arguments: arguments),
        ),
        displayResult ??
            _textPart(
              id: displayPartId,
              sessionId: sessionId,
              messageId: messageId,
              text: "",
            ),
        for (final part in mappedResults)
          if (part.id != displayPartId) part,
      ],
    );
  }

  MessagePart mapResultPart({
    required MessagePart part,
    required String messageId,
    required String sessionId,
  }) {
    return part.copyWith(
      id: resultPartId(
        messageId: messageId,
        backendPartId: part.id,
        isText: part.type == MessagePartType.text,
      ),
      sessionID: sessionId,
      messageID: messageId,
    );
  }

  String resultPartId({
    required String messageId,
    required String backendPartId,
    required bool isText,
  }) {
    return isText ? "$messageId:display" : "$messageId:result:$backendPartId";
  }

  MessagePart _textPart({
    required String id,
    required String sessionId,
    required String messageId,
    required String text,
  }) {
    return MessagePart(
      id: id,
      sessionID: sessionId,
      messageID: messageId,
      type: MessagePartType.text,
      text: text,
      tool: null,
      state: null,
      prompt: null,
      description: null,
      agent: null,
      agentName: null,
      attempt: null,
      retryError: null,
    );
  }

  String _fallbackLine({required String name, required String? arguments}) {
    return arguments == null ? "/$name" : "/$name $arguments";
  }
}
