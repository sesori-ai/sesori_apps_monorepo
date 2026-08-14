import "dart:async";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart" show GenerateSessionMetadataRequest;

import "../api/sesori_server_api.dart";

class SessionMetadataRequestAbortedException({
  required final Object innerError,
  required final StackTrace innerStackTrace,
}) implements Exception;

class SessionMetadataRepository({required final SesoriServerApi _api}) {
  static const int maximumFirstMessageLength = 500;
  final SesoriServerRequestAbortSignal _abortSignal = SesoriServerRequestAbortSignal();

  void beginShutdown() => _abortSignal.abort();

  Future<String> generateTitle({required String firstMessage}) async {
    final normalizedFirstMessage = _clipFirstMessage(firstMessage);
    try {
      final response = await _api.generateSessionMetadata(
        request: GenerateSessionMetadataRequest(firstMessage: normalizedFirstMessage),
        abortSignal: _abortSignal,
      );
      return response.title;
    } on http.RequestAbortedException catch (error, stackTrace) {
      throw SessionMetadataRequestAbortedException(innerError: error, innerStackTrace: stackTrace);
    }
  }

  String _clipFirstMessage(String firstMessage) {
    if (firstMessage.length <= maximumFirstMessageLength) return firstMessage;
    var codeUnitLength = 0;
    final clippedRunes = <int>[];
    for (final rune in firstMessage.runes) {
      final runeLength = rune > 0xFFFF ? 2 : 1;
      if (codeUnitLength + runeLength > maximumFirstMessageLength) break;
      clippedRunes.add(rune);
      codeUnitLength += runeLength;
    }
    return String.fromCharCodes(clippedRunes);
  }
}
