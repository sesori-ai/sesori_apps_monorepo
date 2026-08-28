// Grok Build backend for the Sesori bridge.
//
// Drives the official `grok agent stdio` ACP server through Sesori's generic
// ACP machinery using the user's installed direct-CLI runtime.
export "src/grok_binary.dart";
export "src/grok_identity.dart";
export "src/grok_plugin_impl.dart";
// Plugin-lifecycle entry point: the const descriptor the bridge registers.
export "src/runtime/grok_plugin_descriptor.dart";
