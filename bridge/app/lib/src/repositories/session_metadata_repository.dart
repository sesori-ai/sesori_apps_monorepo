import "dart:async";

import "package:sesori_shared/sesori_shared.dart" show GenerateSessionMetadataRequest;

import "../api/sesori_server_api.dart";

class SessionMetadataRepository({required final SesoriServerApi _api}) {
  static const int maximumFirstMessageLength = 500;

  Future<String> generateTitle({required String firstMessage, required Future<void> shutdownSignal}) async {
    final normalizedFirstMessage = firstMessage.length <= maximumFirstMessageLength
        ? firstMessage
        : firstMessage.substring(0, maximumFirstMessageLength);
    final response = await _api.generateSessionMetadata(
      request: GenerateSessionMetadataRequest(firstMessage: normalizedFirstMessage),
      shutdownSignal: shutdownSignal,
    );
    return response.title;
  }
}
