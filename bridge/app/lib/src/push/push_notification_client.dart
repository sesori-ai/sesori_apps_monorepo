import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart" show SendNotificationPayload;

import "../auth/token_refresher.dart";
import "push_send_exception.dart";

class PushNotificationClient {
  final String authBackendURL;
  final TokenRefresher _tokenRefreshManager;
  final http.Client _client;

  PushNotificationClient({
    required this.authBackendURL,
    required TokenRefresher tokenRefreshManager,
    required http.Client client,
  }) : _tokenRefreshManager = tokenRefreshManager,
       _client = client;

  Future<void> sendNotification(SendNotificationPayload payload) async {
    final token = await _tokenRefreshManager.getAccessToken();
    final response = await _sendPost(payload, token);

    // 401: force refresh and retry once
    if (response.statusCode == 401) {
      final refreshedToken = await _tokenRefreshManager.getAccessToken(forceRefresh: true);
      final retryResponse = await _sendPost(payload, refreshedToken);
      if (retryResponse.statusCode < 200 || retryResponse.statusCode >= 300) {
        throw PushSendException(statusCode: retryResponse.statusCode, isRetry: true);
      }
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PushSendException(statusCode: response.statusCode);
    }
  }

  Future<http.Response> _sendPost(SendNotificationPayload payload, String token) {
    final base = authBackendURL.endsWith("/") ? authBackendURL.substring(0, authBackendURL.length - 1) : authBackendURL;
    return _client.post(
      Uri.parse("$base/notifications/send"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload.toJson()),
    );
  }

  Future<void> dispose() async {
    // Shared http client lifetime is owned by the composition root.
  }
}
