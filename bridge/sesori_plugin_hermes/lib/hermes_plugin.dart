// Hermes Agent backend for the Sesori bridge.
//
// Drives `hermes acp` over the generic ACP machinery (acp_plugin), with
// Hermes-local handling for its unstable model catalog and set-model surface.
export "src/hermes_binary.dart";
export "src/hermes_plugin_impl.dart";
// Plugin-lifecycle entry point: the const descriptor the bridge registers.
export "src/runtime/hermes_plugin_descriptor.dart";
