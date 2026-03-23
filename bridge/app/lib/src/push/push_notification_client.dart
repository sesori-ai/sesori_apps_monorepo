import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_shared/sesori_shared.dart" show SendNotificationPayload;

import "../auth/token_refresher.dart";

class PushNotificationClient {
  final String authBackendURL;
  final TokenRefresher _tokenRefreshManager;
  final http.Client _client = http.Client();

  PushNotificationClient({
    required this.authBackendURL,
    required TokenRefresher tokenRefreshManager,
  }) : _tokenRefreshManager = tokenRefreshManager;

  Future<void> sendNotification(SendNotificationPayload payload) async {
    final token = await _tokenRefreshManager.getAccessToken();
    final response = await _sendPost(payload, token);

    // 401: force refresh and retry once
    if (response.statusCode == 401) {
      final refreshedToken = await _tokenRefreshManager.getAccessToken(forceRefresh: true);
      final retryResponse = await _sendPost(payload, refreshedToken);
      if (retryResponse.statusCode < 200 || retryResponse.statusCode >= 300) {
        throw Exception("[push] notification failed after retry: ${retryResponse.statusCode}");
      }
      return;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception("[push] notification failed: ${response.statusCode}");
    }
  }

  Future<http.Response> _sendPost(SendNotificationPayload payload, String token) {
    return _client.post(
      Uri.parse("$authBackendURL/notifications/send"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(payload.toJson()),
    );
  }
}
