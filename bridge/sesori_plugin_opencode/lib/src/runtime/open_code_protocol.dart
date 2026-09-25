import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart" show SemanticRuntimeVersion;

/// The HTTP protocol a running OpenCode server speaks, detected from
/// `GET /api/info` after the server answered its health probe.
sealed class const OpenCodeProtocol();

/// OpenCode 1.x, and the safe default whenever `/api/info` does not report a
/// 2.x version.
final class const OpenCodeProtocolV1() extends OpenCodeProtocol;

/// OpenCode 2.x, whose `/api/info` reports a version `>= 2.0.0`.
final class const OpenCodeProtocolV2({required final SemanticRuntimeVersion version}) extends OpenCodeProtocol;
