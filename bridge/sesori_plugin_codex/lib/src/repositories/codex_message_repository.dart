import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../codex_config_reader.dart";
import "../session_rollout_reader.dart";

/// Reads Codex rollouts and assembles their command-aware plugin timeline.
class CodexMessageRepository {
  CodexMessageRepository({
    required SessionRolloutReader rolloutReader,
    required CodexConfigReader configReader,
  }) : _rolloutReader = rolloutReader,
       _configReader = configReader;

  final SessionRolloutReader _rolloutReader;
  final CodexConfigReader _configReader;

  String? findPersistedDirectory({required String sessionId}) {
    for (final record in _rolloutReader.listSessions()) {
      if (record.id == sessionId) return record.cwd;
    }
    return null;
  }

  List<PluginMessageWithParts> getMessages({
    required String sessionId,
    required List<PluginCommandInvocationContext> acceptedCommands,
    required Set<String> knownCommandNames,
  }) {
    final path = _rolloutReader.findRolloutPath(sessionId);
    if (path == null) return const [];
    return mapHistory(
      sessionId: sessionId,
      records: _rolloutReader.readMessageRecords(path, sessionId),
      config: _configReader.readDefaults(),
      acceptedCommands: acceptedCommands,
      knownCommandNames: knownCommandNames,
    );
  }

  List<PluginMessageWithParts> mapHistory({
    required String sessionId,
    required List<CodexRolloutMessageRecord> records,
    required CodexConfigDefaults config,
    required List<PluginCommandInvocationContext> acceptedCommands,
    required Set<String> knownCommandNames,
  }) {
    final unusedCommands = [...acceptedCommands]..sort((a, b) => a.acceptedAt.compareTo(b.acceptedAt));
    final out = <PluginMessageWithParts>[];
    int? activeCommandIndex;

    for (final record in records) {
      final message = _mapRecord(
        sessionId: sessionId,
        record: record,
        config: config,
      );
      if (message.info is PluginMessageUser) {
        activeCommandIndex = null;
        final text = message.parts
            .where((part) => part.type == PluginMessagePartType.text)
            .map((part) => part.text ?? "")
            .join();
        final command = _matchCommand(
          text: text,
          acceptedCommands: unusedCommands,
          knownCommandNames: knownCommandNames,
        );
        if (command == null) {
          out.add(message);
          continue;
        }
        activeCommandIndex = out.length;
        out.add(
          PluginMessageWithParts(
            info: PluginMessage.command(
              id: command.context?.backendMessageId ?? message.info.id,
              sessionID: sessionId,
              name: command.name,
              arguments: command.arguments,
              origin: PluginCommandOrigin.manual,
              invocationId: command.context?.invocationId,
              time: message.info.time,
            ),
            parts: const [],
          ),
        );
        continue;
      }

      final commandIndex = activeCommandIndex;
      if (commandIndex != null && message.info is PluginMessageAssistant) {
        out[commandIndex] = _foldCommandResult(
          command: out[commandIndex],
          result: message,
        );
        continue;
      }
      out.add(message);
    }
    return out;
  }

  PluginMessageWithParts _foldCommandResult({
    required PluginMessageWithParts command,
    required PluginMessageWithParts result,
  }) {
    final resultPartId = "${command.info.id}-result";
    final text = result.parts
        .where((part) => part.type == PluginMessagePartType.text)
        .map((part) => part.text ?? "")
        .where((partText) => partText.isNotEmpty)
        .join();
    final parts = [...command.parts];
    if (text.isNotEmpty) {
      final existingIndex = parts.indexWhere((part) => part.id == resultPartId);
      final existingText = existingIndex < 0 ? null : parts[existingIndex].text;
      final aggregate = existingText == null || existingText.isEmpty ? text : "$existingText\n\n$text";
      final part = _textPart(
        id: resultPartId,
        sessionId: command.info.sessionID,
        messageId: command.info.id,
        text: aggregate,
      );
      if (existingIndex < 0) {
        parts.add(part);
      } else {
        parts[existingIndex] = part;
      }
    }
    parts.addAll(
      result.parts
          .where((part) => part.type != PluginMessagePartType.text && part.type.isVisible)
          .map((part) => part.copyWith(messageID: command.info.id)),
    );
    return command.copyWith(parts: parts);
  }

  _CodexHistoryCommand? _matchCommand({
    required String text,
    required List<PluginCommandInvocationContext> acceptedCommands,
    required Set<String> knownCommandNames,
  }) {
    for (var index = 0; index < acceptedCommands.length; index++) {
      final context = acceptedCommands[index];
      if (_commandBody(context.name, context.arguments) != text) continue;
      acceptedCommands.removeAt(index);
      final arguments = context.arguments;
      return _CodexHistoryCommand(
        name: _normalizeCommand(context.name),
        arguments: arguments == null || arguments.isEmpty ? null : arguments,
        context: context,
      );
    }
    if (!text.startsWith("/")) return null;
    final separator = text.indexOf(" ");
    final name = text.substring(1, separator < 0 ? text.length : separator);
    if (!knownCommandNames.map(_normalizeCommand).contains(name)) return null;
    final arguments = separator < 0 ? null : text.substring(separator + 1);
    return _CodexHistoryCommand(
      name: name,
      arguments: arguments == null || arguments.isEmpty ? null : arguments,
      context: null,
    );
  }

  static String _commandBody(String name, String? arguments) {
    final normalizedName = _normalizeCommand(name);
    return arguments == null || arguments.isEmpty ? "/$normalizedName" : "/$normalizedName $arguments";
  }

  static String _normalizeCommand(String name) => name.startsWith("/") ? name.substring(1) : name;

  PluginMessageWithParts _mapRecord({
    required String sessionId,
    required CodexRolloutMessageRecord record,
    required CodexConfigDefaults config,
  }) {
    final time = record.timestamp == null
        ? null
        : PluginMessageTime(
            created: record.timestamp!.millisecondsSinceEpoch,
            completed: null,
          );
    final info = record.role == CodexRolloutMessageRole.user
        ? PluginMessage.user(
            id: record.id,
            sessionID: sessionId,
            agent: null,
            time: time,
          )
        : PluginMessage.assistant(
            id: record.id,
            sessionID: sessionId,
            agent: "codex",
            modelID: record.modelId ?? config.model,
            providerID: record.providerId ?? config.modelProvider ?? "openai",
            time: time,
          );
    final tool = record.tool;
    return PluginMessageWithParts(
      info: info,
      parts: [
        for (var index = 0; index < record.texts.length; index++)
          PluginMessagePart(
            id: "${record.id}-p$index",
            sessionID: sessionId,
            messageID: record.id,
            type: PluginMessagePartType.text,
            text: record.texts[index],
            tool: null,
            state: null,
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
        if (tool != null)
          PluginMessagePart(
            id: "${record.id}-tool",
            sessionID: sessionId,
            messageID: record.id,
            type: PluginMessagePartType.tool,
            text: null,
            tool: tool.name,
            state: PluginToolState(
              status: tool.status == CodexRolloutToolStatus.completed
                  ? PluginToolStatus.completed
                  : PluginToolStatus.running,
              title: tool.title,
              output: tool.output,
              error: null,
            ),
            prompt: null,
            description: null,
            agent: null,
            agentName: null,
            attempt: null,
            retryError: null,
          ),
      ],
    );
  }

  PluginMessagePart _textPart({
    required String id,
    required String sessionId,
    required String messageId,
    required String text,
  }) => PluginMessagePart(
    id: id,
    sessionID: sessionId,
    messageID: messageId,
    type: PluginMessagePartType.text,
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

class _CodexHistoryCommand {
  const _CodexHistoryCommand({
    required this.name,
    required this.arguments,
    required this.context,
  });

  final String name;
  final String? arguments;
  final PluginCommandInvocationContext? context;
}
