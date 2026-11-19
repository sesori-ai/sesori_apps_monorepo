import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "plugin_command_mapper.dart";
import "plugin_to_shared_mapping.dart";

/// Maps plugin-level message types to shared [Message] types.
extension PluginMessageMapper on PluginMessage {
  Message toSharedMessage({required String sessionId}) => switch (this) {
    PluginMessageUser(:final id, :final agent, :final time, :final promptId, :final invocation) => Message.user(
      id: id,
      sessionID: sessionId,
      agent: agent,
      time: time.toShared(),
      promptId: promptId,
      // A plugin names a run from its backend's record; otherwise bridge core
      // names the commands it sent itself.
      invocation: invocation?.toShared(),
      handoff: null,
    ),
    PluginMessageAssistant(
      :final id,
      :final agent,
      :final modelID,
      :final providerID,
      :final sender,
      :final time,
    ) =>
      Message.assistant(
        id: id,
        sessionID: sessionId,
        agent: agent,
        modelID: modelID,
        providerID: providerID,
        sender: sender.toShared(),
        time: time.toShared(),
      ),
    PluginMessageError(
      :final id,
      :final agent,
      :final modelID,
      :final providerID,
      :final errorName,
      :final errorMessage,
      :final kind,
      :final time,
    ) =>
      Message.error(
        id: id,
        sessionID: sessionId,
        agent: agent,
        modelID: modelID,
        providerID: providerID,
        errorName: errorName,
        errorMessage: errorMessage,
        kind: kind.toShared(),
        time: time.toShared(),
      ),
  };
}

extension on PluginErrorKind {
  MessageErrorKind toShared() => switch (this) {
    PluginErrorKind.failure => MessageErrorKind.failure,
    PluginErrorKind.stopped => MessageErrorKind.stopped,
  };
}

extension on PluginMessageSender {
  MessageSender toShared() => switch (this) {
    PluginMessageSender.agent => MessageSender.agent,
    PluginMessageSender.system => MessageSender.system,
    PluginMessageSender.unknown => MessageSender.unknown,
  };
}

extension on PluginMessageTime? {
  MessageTime? toShared() {
    final time = this;
    return time == null ? null : MessageTime(created: time.created, completed: time.completed);
  }
}

extension PluginMessageWithPartsMapper on PluginMessageWithParts {
  MessageWithParts toSharedMessageWithParts({required String sessionId}) {
    // Backends emit unknown parts for content blocks they cannot model
    // (e.g. Claude's server_tool_use); skip them like the live event path.
    final visibleParts = [
      for (final part in parts)
        if (part is! PluginMessagePartUnknown) ?part.withoutSystemContext(),
    ];
    return MessageWithParts(
      info: switch ((info, visibleParts.whereType<PluginMessagePartText>().toList(growable: false))) {
        // The notice the bridge sent shows as the Sesori row its live echo
        // became, as no harness records the bridge's stamp.
        (PluginMessageUser(:final id, :final time), [final text]) when parseSessionNotice(text: text.text) != null =>
          sesoriNoticeRow(id: id, sessionId: sessionId, time: time.toShared()),
        (final message, _) => message.toSharedMessage(sessionId: sessionId),
      },
      parts: [for (final part in visibleParts) part.toShared(sessionId: sessionId).withoutNoticeFrame()],
    );
  }
}

/// The row a Sesori notice prompt shows as: Sesori's own message, live and on
/// reload alike.
Message sesoriNoticeRow({required String id, required String sessionId, required MessageTime? time}) =>
    Message.assistant(
      id: id,
      sessionID: sessionId,
      agent: null,
      modelID: null,
      providerID: null,
      sender: MessageSender.sesori,
      time: time,
    );

extension PluginMessagePartSystemContext on PluginMessagePart {
  /// This part without the bridge's notes, or `null` when the notes were
  /// all it held. Live parts carry no role, so history and the live path strip
  /// every text part by the same rule and the stored transcript matches the
  /// live event.
  PluginMessagePart? withoutSystemContext() {
    final part = this;
    if (part is! PluginMessagePartText) return part;
    final text = stripSystemContext(text: part.text);
    if (text == null) return null;
    return identical(text, part.text) ? part : part.copyWith(text: text);
  }
}

extension MessagePartNoticeFrame on MessagePart {
  /// This part with only its summary when it is a Sesori notice, which shows
  /// to the user as that one line, and with the page the notice settles, so
  /// the line can reopen it. Text-based for the same reason as
  /// [PluginMessagePartSystemContext.withoutSystemContext].
  MessagePart withoutNoticeFrame() {
    final part = this;
    if (part is! MessagePartText) return part;
    final notice = parseSessionNotice(text: part.text);
    if (notice == null) return part;
    return part.copyWith(text: notice.summary, noticePageRequestId: notice.pageRequestId);
  }
}

extension PluginMessagePartsMapper on Iterable<PluginMessageWithParts> {
  List<MessageWithParts> toSharedMessageWithParts({required String sessionId}) {
    return map((message) => message.toSharedMessageWithParts(sessionId: sessionId)).toList(growable: false);
  }
}

extension PluginMessagePromptDefaultsMapper on List<PluginMessageWithParts> {
  SessionPromptDefaults? latestPromptDefaults() {
    for (var index = length - 1; index >= 0; index--) {
      final ({String? agent, String? modelID, String? providerID, String? variant})? selection =
          switch (this[index].info) {
            PluginMessageAssistant(
              sender: PluginMessageSender.agent,
              :final agent,
              :final modelID,
              :final providerID,
              :final variant,
            ) ||
            PluginMessageError(:final agent, :final modelID, :final providerID, :final variant) => (
              agent: agent,
              modelID: modelID,
              providerID: providerID,
              variant: variant,
            ),
            PluginMessageAssistant() || PluginMessageUser() => null,
          };
      if (selection == null) continue;
      final (:agent, :modelID, :providerID, :variant) = selection;
      if (modelID == null && providerID == null) continue;
      return SessionPromptDefaults(
        agent: agent,
        model: modelID == null || providerID == null
            ? null
            : AgentModel(providerID: providerID, modelID: modelID, variant: variant),
      );
    }
    return null;
  }
}
