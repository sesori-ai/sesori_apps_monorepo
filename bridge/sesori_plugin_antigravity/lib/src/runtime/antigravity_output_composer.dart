import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/mappers/antigravity_authorization_mapper.dart";
import "../repositories/mappers/antigravity_stderr_mapper.dart";

/// Per-process interception; the ACP client still owns buffering and teardown.
class const AntigravityOutputComposer({
  required final AntigravityAuthorizationMapper authorizationMapper,
  required final AntigravityStderrMapper stderrMapper,
}) {
  static const authenticationHint =
      "Authenticate Antigravity from a current Sesori mobile or desktop client, then retry.";

  AcpOutputInterceptors compose() => (
    // Standard image JSON passes through after this small prefix, without a
    // whole-line copy or an image-size restriction in the authorization gate.
    stdout: AcpOutputInterceptor(
      maxLineBytes: AntigravityAuthorizationMapper.prefix.length + 16384 + 2,
      prefix: AcpOutputPrefix(
        length: AntigravityAuthorizationMapper.prefix.length,
        matches: authorizationMapper.matchesPrefix,
      ),
      consumeLine: _consumeStdout,
    ),
    stderr: AcpOutputInterceptor(maxLineBytes: 65536, consumeLine: stderrMapper.consumeLine),
  );

  bool _consumeStdout({required List<int> line}) {
    if (authorizationMapper.parseLine(line: line) == null) return false;
    throw const PluginAuthenticationRequiredException(
      "authenticate",
      actionHint: authenticationHint,
      message: "Antigravity requires personal Google authentication",
    );
  }

  // ignore: no_slop_linter/prefer_specific_type, preserve other initialization failures unchanged
  Object mapInitializationFailure({required Object error}) {
    if (error case AcpOutputInterceptionException(cause: PluginAuthenticationRequiredException())) {
      return PluginAuthenticationRequiredException(
        "authenticate",
        actionHint: authenticationHint,
        message: "Antigravity requires personal Google authentication",
        cause: error,
      );
    }
    return error;
  }
}
