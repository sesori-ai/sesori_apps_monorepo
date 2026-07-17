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
    final acceptedCommandByRecord = _matchAcceptedCommands(
      records: records,
      acceptedCommands: acceptedCommands,
    );
    final out = <PluginMessageWithParts>[];
    int? activeCommandIndex;

    for (var recordIndex = 0; recordIndex < records.length; recordIndex++) {
      final record = records[recordIndex];
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
          acceptedCommand: acceptedCommandByRecord[recordIndex],
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
    required PluginCommandInvocationContext? acceptedCommand,
    required Set<String> knownCommandNames,
  }) {
    if (acceptedCommand != null) {
      final arguments = acceptedCommand.arguments;
      return _CodexHistoryCommand(
        name: _normalizeCommand(acceptedCommand.name),
        arguments: arguments == null || arguments.isEmpty ? null : arguments,
        context: acceptedCommand,
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

  Map<int, PluginCommandInvocationContext> _matchAcceptedCommands({
    required List<CodexRolloutMessageRecord> records,
    required List<PluginCommandInvocationContext> acceptedCommands,
  }) {
    final contextsByBody = <String, List<({PluginCommandInvocationContext context, int sourceOrder})>>{};
    for (var index = 0; index < acceptedCommands.length; index++) {
      final context = acceptedCommands[index];
      (contextsByBody[_commandBody(context.name, context.arguments)] ??= []).add(
        (context: context, sourceOrder: index),
      );
    }

    final recordsByBody = <String, List<({int sourceOrder, DateTime? timestamp})>>{};
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      if (record.role != CodexRolloutMessageRole.user) continue;
      final body = record.texts.join();
      if (!contextsByBody.containsKey(body)) continue;
      (recordsByBody[body] ??= []).add(
        (sourceOrder: index, timestamp: record.timestamp),
      );
    }

    final matches = <int, PluginCommandInvocationContext>{};
    for (final entry in contextsByBody.entries) {
      final contexts = [...entry.value]
        ..sort((a, b) {
          final byTime = a.context.acceptedAt.compareTo(b.context.acceptedAt);
          return byTime != 0 ? byTime : a.sourceOrder.compareTo(b.sourceOrder);
        });
      final candidates = recordsByBody[entry.key];
      if (candidates == null) continue;
      final timestamped = candidates.where((record) => record.timestamp != null).toList();

      while (contexts.isNotEmpty && timestamped.isNotEmpty) {
        var bestContextIndex = 0;
        var bestRecordIndex = 0;
        var bestDistance = _timestampDistance(
          acceptedAt: contexts.first.context.acceptedAt,
          timestamp: timestamped.first.timestamp!,
        );
        for (var contextIndex = 0; contextIndex < contexts.length; contextIndex++) {
          final context = contexts[contextIndex];
          for (var recordIndex = 0; recordIndex < timestamped.length; recordIndex++) {
            final record = timestamped[recordIndex];
            final distance = _timestampDistance(
              acceptedAt: context.context.acceptedAt,
              timestamp: record.timestamp!,
            );
            if (distance < bestDistance ||
                (distance == bestDistance && record.sourceOrder < timestamped[bestRecordIndex].sourceOrder) ||
                (distance == bestDistance &&
                    record.sourceOrder == timestamped[bestRecordIndex].sourceOrder &&
                    contextIndex < bestContextIndex)) {
              bestContextIndex = contextIndex;
              bestRecordIndex = recordIndex;
              bestDistance = distance;
            }
          }
        }
        final context = contexts.removeAt(bestContextIndex).context;
        final record = timestamped.removeAt(bestRecordIndex);
        matches[record.sourceOrder] = context;
      }

      final withoutTimestamps = candidates.where((record) => record.timestamp == null);
      for (final record in withoutTimestamps) {
        if (contexts.isEmpty) break;
        matches[record.sourceOrder] = contexts.removeAt(0).context;
      }
    }
    return matches;
  }

  static int _timestampDistance({required int acceptedAt, required DateTime timestamp}) =>
      (acceptedAt - timestamp.millisecondsSinceEpoch).abs();

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
