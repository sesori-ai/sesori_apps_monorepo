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
    final mappedNonTextResults = [
      for (final part in resultParts)
        if (part.type != MessagePartType.text)
          mapResultPart(
            part: part,
            messageId: messageId,
            sessionId: sessionId,
          ),
    ];
    final displayResult = mapDisplayPart(
      messageId: messageId,
      sessionId: sessionId,
      resultParts: resultParts,
    );
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
        displayResult,
        ...mappedNonTextResults,
      ],
    );
  }

  MessagePart mapDisplayPart({
    required String messageId,
    required String sessionId,
    required Iterable<MessagePart> resultParts,
  }) {
    final textParts = resultParts.where((part) => part.type == MessagePartType.text);
    return _textPart(
      id: "$messageId:display",
      sessionId: sessionId,
      messageId: messageId,
      text: textParts.map((part) => part.text ?? "").join(),
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
    return arguments == null || arguments.isEmpty ? "/$name" : "/$name $arguments";
  }
}
