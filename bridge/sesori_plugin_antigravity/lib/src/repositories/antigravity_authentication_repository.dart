import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/antigravity_acp_api.dart";
import "../builders/antigravity_launch_spec_builder.dart";
import "../clients/antigravity_loopback_client.dart";
import "../foundation/antigravity_authentication_budget.dart";
import "../models/antigravity_authentication.dart";
import "../models/antigravity_runtime_pair.dart";
import "mappers/antigravity_authorization_mapper.dart";

/// Scoped to one authentication attempt. Subscribe before authenticate; the
/// operation owns cancellation and awaits authenticate before disposing peers.
class AntigravityAuthenticationRepository({
  required final AntigravityAcpApi _acpApi,
  required final AntigravityLoopbackClient _loopbackClient,
  required final AntigravityAuthorizationMapper _authorizationMapper,
  required final AntigravityLaunchSpecBuilder _launchSpecBuilder,
}) {
  final StreamController<Uri> _authorizations = StreamController.broadcast(sync: true);

  Stream<Uri> get authorizations => _authorizations.stream;

  Future<void> authenticate({
    required AntigravityRuntimePair pair,
    required Map<String, String> environment,
    required AntigravityAuthenticationBudget budget,
  }) async {
    try {
      await _acpApi.authenticate(
        launchSpec: _launchSpecBuilder.build(pair: pair, cwd: null, environment: environment),
        budget: budget,
        stdoutInterceptor: AcpOutputInterceptor(
          maxLineBytes: 65536,
          consumeLine: ({required line}) {
            final authorization = _authorizationMapper.parseLine(line: line);
            if (authorization == null) return false;
            _authorizations.add(authorization);
            return true;
          },
        ),
      );
    } on PluginStartAbortedException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AntigravityAuthenticationException(message: "ACP login failed", cause: error),
        stackTrace,
      );
    }
  }

  Future<AntigravityCallbackResult> forward({
    required Uri callbackUri,
    required AntigravityAuthenticationBudget budget,
  }) async {
    try {
      final status = await _loopbackClient.forward(callbackUri: callbackUri, budget: budget);
      return status >= 200 && status < 300
          ? const AntigravityCallbackAccepted()
          : AntigravityCallbackRejected(statusCode: status);
    } on PluginStartAbortedException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AntigravityAuthenticationException(message: "Callback delivery failed", cause: error),
        stackTrace,
      );
    }
  }

  Future<void> dispose() async {
    _loopbackClient.dispose();
    await _authorizations.close();
  }
}
