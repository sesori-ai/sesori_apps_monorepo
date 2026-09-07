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
    // ACP lines can contain four 20MiB image candidates and redundant raw copies.
    // Authorization URLs themselves retain the mapper's much smaller 16KiB bound.
    stdout: AcpOutputInterceptor(maxLineBytes: 256 * 1024 * 1024, consumeLine: _consumeStdout),
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
