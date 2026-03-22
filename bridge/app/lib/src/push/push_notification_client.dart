import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show SendNotificationPayload;

import "../auth/access_token_provider.dart";

class PushNotificationClient {
  final String authBackendURL;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client = http.Client();

  PushNotificationClient({
    required this.authBackendURL,
    required AccessTokenProvider accessTokenProvider,
  }) : _accessTokenProvider = accessTokenProvider;

  Future<void> sendNotification(SendNotificationPayload payload) async {
    try {
      final response = await _client.post(
        Uri.parse("$authBackendURL/notifications/send"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${_accessTokenProvider.accessToken}",
        },
        body: jsonEncode(payload.toJson()),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        Log.w("[push] notification failed: ${response.statusCode}");
      }
    } catch (e) {
      Log.w("[push] notification error: $e");
    }
  }
}
