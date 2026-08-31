import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/deepseek_acp_api.dart";
import "../api/models/deepseek_protocol_dto.dart";
import "../deepseek_event_mapper.dart";
import "../deepseek_message_time_parser.dart";

class DeepSeekHistoryRepository({
  required final DeepSeekAcpApi api,
  required final DeepSeekEventMapper eventMapper,
  required final String pluginId,
  required final DeepSeekMessageTimeParser messageTimeParser,
}) {
  static const int _maxPages = 100;
  static const int _pageSize = 100;

  Future<List<PluginMessageWithParts>> getMessages({
    required AcpStdioClient client,
    required String sessionId,
  }) async {
    final collector = AcpReplayCollector(
      sessionId: sessionId,
      agentId: pluginId,
      initialUserMessageId: null,
      messageIdOverride: ({required acpMessageId}) => acpMessageId,
      messageTimeResolver: ({required params}) => messageTimeParser.parse(params),
      haltClassifier: eventMapper.classifyHaltNotice,
    );
    int? cursor;
    final pages = <List<DeepSeekSessionUpdateEnvelopeDto>>[];
    try {
      for (var page = 0; page < _maxPages; page++) {
        final response = await api.history(
          client: client,
          sessionId: sessionId,
          beforeSeq: cursor,
          maxMessages: _pageSize,
          timeout: const Duration(minutes: 2),
        );
        pages.add(response.updates);
        switch (response) {
          case DeepSeekTerminalHistoryResponseDto():
            for (final updates in pages.reversed) {
              for (final envelope in updates) {
                collector.consume(envelope.toJson());
              }
            }
            return collector.buildWithAssistantSelection(
              modelId: eventMapper.modelForSession(sessionId: sessionId),
              providerId: eventMapper.providerForSession(sessionId: sessionId),
              variant: null,
            );
          case DeepSeekPaginatedHistoryResponseDto(:final nextBeforeSeq):
            if (cursor != null && nextBeforeSeq >= cursor) {
              throw const FormatException("DeepSeek history cursor did not progress");
            }
            cursor = nextBeforeSeq;
        }
      }
      throw const FormatException("DeepSeek history exceeded page limit");
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        PluginOperationException(
          DeepSeekAcpApi.historyMethod,
          message: "DeepSeek history replay failed",
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
