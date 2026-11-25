import "dart:io" show HttpException, HttpStatus;

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show SesoriMcpLaunch;

/// The Sesori bridge's loopback MCP endpoint, which answers one JSON-RPC
/// message per POST for the bearer token of a [SesoriMcpLaunch].
class SesoriBridgeMcpApi({required final http.Client _client}) {
  /// The JSON-RPC reply to [message]. Throws [HttpException] when the bridge
  /// refuses it, as it does a token it did not mint.
  Future<String> send({required SesoriMcpLaunch launch, required String message}) async {
    final response = await _client.post(
      Uri.parse(launch.url),
      headers: {"authorization": "Bearer ${launch.token}", "content-type": "application/json"},
      body: message,
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException("The Sesori MCP endpoint answered ${response.statusCode}");
    }
    return response.body;
  }
}
