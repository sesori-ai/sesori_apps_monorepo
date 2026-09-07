import "dart:async";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../foundation/antigravity_authentication_budget.dart";

/// One-attempt HTTP boundary. Composition injects a dedicated client; it is never
/// shared with other requests. Only the service-authorized callback is sent.
class AntigravityLoopbackClient({required final HttpClient _client}) {
  this {
    _client.findProxy = (_) => "DIRECT";
  }

  Future<int> forward({required Uri callbackUri, required AntigravityAuthenticationBudget budget}) async {
    budget.remaining;
    Future<int> send() async {
      final request = await _client.getUrl(callbackUri);
      budget.remaining;
      request.followRedirects = false;
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    }

    final work = send();
    final settled = work.then<AsyncError?>(
      (_) => null,
      onError: AsyncError.new,
    );
    final int statusCode;
    try {
      statusCode = await Future.any<int>([
        work,
        budget.abortSignal.whenAborted.then<int>((_) => throw const PluginStartAbortedException()),
      ]).timeout(budget.remaining);
    } finally {
      _client.close(force: true);
      // Forced close settles the actual request. Its secondary failure must not
      // replace the abort/timeout that initiated closure, or escape afterwards.
      await settled;
    }
    budget.remaining;
    return statusCode;
  }

  void dispose() => _client.close(force: true);
}
