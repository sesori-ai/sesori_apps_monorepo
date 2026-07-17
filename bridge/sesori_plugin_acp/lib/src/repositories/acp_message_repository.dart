import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../acp_command_identity_builder.dart";
import "../acp_session_loader.dart";

/// Layer-2 assembly of ACP replay records into plugin timeline messages.
class AcpMessageRepository {
  const AcpMessageRepository();

  List<PluginMessageWithParts> mapHistory({
    required String sessionId,
    required String agentId,
    required String? modelId,
    required String? providerId,
    required List<AcpReplayMessage> records,
    required List<PluginCommandInvocationContext> acceptedCommands,
    required Set<String> knownCommandNames,
  }) {
    final acceptedContextsByRecord = _matchAcceptedCommands(
      records: records,
      acceptedCommands: acceptedCommands,
    );
    final normalizedKnownCommandNames = knownCommandNames.map(_normalizeCommandName).toSet();
    final output = <PluginMessageWithParts>[];
    _HistoryCommand? activeCommand;

    for (var recordIndex = 0; recordIndex < records.length; recordIndex++) {
      final record = records[recordIndex];
      if (record.role == AcpReplayRole.user) {
        activeCommand = null;
        final correlation = _correlateCommand(
          text: record.text,
          context: acceptedContextsByRecord[recordIndex],
          knownCommandNames: normalizedKnownCommandNames,
        );
        if (correlation != null) {
          final context = correlation.context;
          final messageId = context == null
              ? record.id
              : AcpCommandIdentityBuilder.messageId(
                  sessionId: sessionId,
                  invocationId: context.invocationId,
                );
          activeCommand = _HistoryCommand(
            outputIndex: output.length,
            messageId: messageId,
            resultPartId: "$messageId-result",
          );
          output.add(
            PluginMessageWithParts(
              info: PluginMessage.command(
                id: messageId,
                sessionID: sessionId,
                name: correlation.name,
                arguments: correlation.arguments,
                origin: PluginCommandOrigin.manual,
                invocationId: context?.invocationId,
                time: null,
              ),
              parts: const [],
            ),
          );
          continue;
        }
      }

      final mapped = _mapRecord(
        sessionId: sessionId,
        agentId: agentId,
        modelId: modelId,
        providerId: providerId,
        record: record,
      );
      final command = activeCommand;
      if (command != null && mapped.info is PluginMessageAssistant) {
        output[command.outputIndex] = _foldCommandResult(
          command: output[command.outputIndex],
          result: mapped,
          commandState: command,
        );
        continue;
      }
      output.add(mapped);
    }
    return output;
  }

  PluginMessageWithParts _foldCommandResult({
    required PluginMessageWithParts command,
    required PluginMessageWithParts result,
    required _HistoryCommand commandState,
  }) {
    final parts = [...command.parts];
    for (final part in result.parts) {
      if (part.type != PluginMessagePartType.text) {
        parts.add(part.copyWith(messageID: commandState.messageId));
        continue;
      }
      final text = part.text ?? "";
      final resultIndex = commandState.resultIndex;
      if (resultIndex == null) {
        commandState.resultIndex = parts.length;
        parts.add(
          part.copyWith(
            id: commandState.resultPartId,
            messageID: commandState.messageId,
          ),
        );
      } else {
        final prior = parts[resultIndex];
        parts[resultIndex] = prior.copyWith(text: "${prior.text ?? ""}$text");
      }
    }
    return command.copyWith(parts: parts);
  }

  _AcpCommandCorrelation? _correlateCommand({
    required String text,
    required PluginCommandInvocationContext? context,
    required Set<String> knownCommandNames,
  }) {
    if (context != null) {
      return _AcpCommandCorrelation(
        name: _normalizeCommandName(context.name),
        arguments: _normalizeArguments(context.arguments),
        context: context,
      );
    }
    if (!text.startsWith("/")) return null;
    final separator = text.indexOf(" ");
    final name = text.substring(1, separator < 0 ? text.length : separator);
    if (!knownCommandNames.contains(name)) return null;
    return _AcpCommandCorrelation(
      name: name,
      arguments: separator < 0 ? null : _normalizeArguments(text.substring(separator + 1)),
      context: null,
    );
  }

  Map<int, PluginCommandInvocationContext> _matchAcceptedCommands({
    required List<AcpReplayMessage> records,
    required List<PluginCommandInvocationContext> acceptedCommands,
  }) {
    final replayIndexesByBody = <String, List<int>>{};
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      if (record.role != AcpReplayRole.user) continue;
      (replayIndexesByBody[record.text] ??= []).add(index);
    }

    final contextsByNewest = acceptedCommands.asMap().entries.toList()
      ..sort((a, b) {
        final acceptedAt = b.value.acceptedAt.compareTo(a.value.acceptedAt);
        return acceptedAt != 0 ? acceptedAt : b.key.compareTo(a.key);
      });
    final matched = <int, PluginCommandInvocationContext>{};
    for (final entry in contextsByNewest) {
      final context = entry.value;
      final replayIndexes = replayIndexesByBody[_commandBody(context.name, context.arguments ?? "")];
      if (replayIndexes == null || replayIndexes.isEmpty) continue;
      matched[replayIndexes.removeLast()] = context;
    }
    return matched;
  }

  static String _commandBody(String name, String arguments) {
    final normalizedName = _normalizeCommandName(name);
    return arguments.isEmpty ? "/$normalizedName" : "/$normalizedName $arguments";
  }

  static String _normalizeCommandName(String name) => name.startsWith("/") ? name.substring(1) : name;

  static String? _normalizeArguments(String? arguments) {
    return arguments == null || arguments.isEmpty ? null : arguments;
  }

  PluginMessageWithParts _mapRecord({
    required String sessionId,
    required String agentId,
    required String? modelId,
    required String? providerId,
    required AcpReplayMessage record,
  }) {
    final errorName = record.errorName;
    final info = errorName != null
        ? PluginMessage.error(
            id: record.id,
            sessionID: sessionId,
            agent: agentId,
            modelID: modelId,
            providerID: providerId,
            errorName: errorName,
            errorMessage: record.errorMessage ?? "Unknown error",
            time: null,
          )
        : record.role == AcpReplayRole.user
        ? PluginMessage.user(
            id: record.id,
            sessionID: sessionId,
            agent: null,
            time: null,
          )
        : PluginMessage.assistant(
            id: record.id,
            sessionID: sessionId,
            agent: agentId,
            modelID: modelId,
            providerID: providerId,
            time: null,
          );
    return PluginMessageWithParts(
      info: info,
      parts: [
        if (errorName == null && record.reasoning.isNotEmpty)
          _textPart(
            id: "${record.id}-reasoning",
            sessionId: sessionId,
            messageId: record.id,
            type: PluginMessagePartType.reasoning,
            text: record.reasoning,
          ),
        if (errorName == null && record.text.isNotEmpty)
          _textPart(
            id: "${record.id}-text",
            sessionId: sessionId,
            messageId: record.id,
            type: PluginMessagePartType.text,
            text: record.text,
          ),
        if (errorName == null)
          for (final tool in record.tools)
            PluginMessagePart(
              id: "$sessionId-tool-${tool.id}-call",
              sessionID: sessionId,
              messageID: record.id,
              type: PluginMessagePartType.tool,
              text: null,
              tool: tool.name,
              state: PluginToolState(
                status: tool.status,
                title: tool.title,
                output: tool.output,
                error: tool.status == PluginToolStatus.error ? tool.output : null,
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
    required PluginMessagePartType type,
    required String text,
  }) => PluginMessagePart(
    id: id,
    sessionID: sessionId,
    messageID: messageId,
    type: type,
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

class _HistoryCommand {
  _HistoryCommand({
    required this.outputIndex,
    required this.messageId,
    required this.resultPartId,
  });

  final int outputIndex;
  final String messageId;
  final String resultPartId;
  int? resultIndex;
}

class _AcpCommandCorrelation {
  const _AcpCommandCorrelation({
    required this.name,
    required this.arguments,
    required this.context,
  });

  final String name;
  final String? arguments;
  final PluginCommandInvocationContext? context;
}
