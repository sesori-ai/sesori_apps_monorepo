import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../auth/token_refresher.dart";
import "models/session_metadata.dart";

class MetadataService {
  final String _baseUrl;
  final TokenRefresher _tokenRefresher;
  final http.Client _client;

  MetadataService({
    required http.Client client,
    required String baseUrl,
    required TokenRefresher tokenRefresher,
  }) : _client = client,
       _baseUrl = baseUrl,
       _tokenRefresher = tokenRefresher;

  Future<SessionMetadata?> generate({required String firstMessage}) async {
    try {
      final truncated = firstMessage.length > 500 ? firstMessage.substring(0, 500) : firstMessage;

      final token = await _tokenRefresher.getAccessToken();
      final response = await _post(
        firstMessage: truncated,
        token: token,
      );

      if (response.statusCode == 401) {
        final refreshedToken = await _tokenRefresher.getAccessToken(forceRefresh: true);
        final retryResponse = await _post(
          firstMessage: truncated,
          token: refreshedToken,
        );
        return _parseResponse(retryResponse);
      }

      return _parseResponse(response);
    } on Object catch (e) {
      Log.w("[MetadataService] generate failed: $e");
      return null;
    }
  }

  Future<http.Response> _post({
    required String firstMessage,
    required String token,
  }) {
    final base = _baseUrl.endsWith("/") ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    return _client
        .post(
          Uri.parse("$base/sessions/generate-metadata"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
          body: jsonEncode({"firstMessage": firstMessage}),
        )
        .timeout(const Duration(seconds: 45));
  }

  SessionMetadata? _parseResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      Log.w(
        "[MetadataService] unexpected status ${response.statusCode}",
      );
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      Log.w("[MetadataService] unexpected response body type");
      return null;
    }

    final title = decoded["title"];
    final branchName = decoded["branchName"];
    final worktreeName = decoded["worktreeName"];

    if (title is! String || branchName is! String || worktreeName is! String) {
      Log.w("[MetadataService] missing or invalid fields in response");
      return null;
    }

    return SessionMetadata(
      title: title,
      branchName: branchName,
      worktreeName: worktreeName,
    );
  }
}
