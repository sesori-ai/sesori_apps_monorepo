// GitHub Copilot CLI backend for the Sesori bridge.
//
// Drives `copilot --no-auto-update --acp` through the shared ACP package while
// keeping Copilot identity, launch arguments, and protocol policy local.
export "src/copilot_binary.dart";
export "src/copilot_identity.dart";
export "src/copilot_plugin_impl.dart";
export "src/runtime/copilot_plugin_descriptor.dart";
export "src/runtime/copilot_runtime_manifest.dart";
