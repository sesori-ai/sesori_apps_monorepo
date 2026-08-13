// Hermes Agent backend for the Sesori bridge.
//
// Drives `hermes acp` over the generic ACP machinery (acp_plugin). Hermes is
// a stock ACP v1 server (protocol version 1), so the plugin core is policy
// only — no harness-specific protocol extensions.
export "src/hermes_binary.dart";
export "src/hermes_identity.dart";
export "src/hermes_plugin_impl.dart";
// Plugin-lifecycle entry point: the const descriptor the bridge registers.
export "src/runtime/hermes_plugin_descriptor.dart";
export "src/runtime/hermes_runtime_manifest.dart";
