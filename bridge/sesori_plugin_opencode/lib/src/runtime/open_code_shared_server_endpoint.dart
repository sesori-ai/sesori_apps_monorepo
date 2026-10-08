import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart" show SemanticRuntimeVersion;

/// A healthy, compatible OpenCode 2.x shared background server the bridge can
/// attach to without owning it. [host] is already connectable (a wildcard bind
/// address is mapped to loopback).
class const OpenCodeSharedServerEndpoint({
  required final String host,
  required final int port,
  required final String? password,
  required final SemanticRuntimeVersion version,
}) {
  /// Structured so an IPv6 literal host is bracketed.
  String get url => Uri(scheme: "http", host: host, port: port).toString();
}
