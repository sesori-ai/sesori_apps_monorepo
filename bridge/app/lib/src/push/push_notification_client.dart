import "dart:convert";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

class PushNotificationClient {
  final String authBackendURL;
  final String Function() accessTokenProvider;
  final http.Client _client = http.Client();

  PushNotificationClient({
    required this.authBackendURL,
    required this.accessTokenProvider,
  });

  Future<void> sendNotification({
    required String category,
    required String title,
    required String body,
    String? collapseKey,
    Map<String, String>? data,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse("$authBackendURL/notifications/send"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${accessTokenProvider()}",
        },
        body: jsonEncode(
          <String, Object?>{
            "category": category,
            "title": title,
            "body": body,
            "collapseKey": collapseKey,
            "data": data,
          }..removeWhere((_, value) => value == null),
        ),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        Log.w("[push] notification failed: ${response.statusCode}");
      }
    } catch (e) {
      Log.w("[push] notification error: $e");
    }
  }
}
