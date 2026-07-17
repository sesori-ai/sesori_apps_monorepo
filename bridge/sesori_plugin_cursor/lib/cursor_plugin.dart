// Cursor backend for the Sesori bridge.
//
// Drives `cursor-agent acp` over the generic ACP machinery (acp_plugin),
// adding Cursor's `cursor/*` extensions and its configOptions model picker.
export "src/cursor_approval_registry.dart";
export "src/cursor_binary.dart";
export "src/cursor_event_mapper.dart";
export "src/cursor_plugin_impl.dart";
export "src/dispatchers/cursor_turn_configuration_dispatcher.dart";
// Plugin-lifecycle entry point: the const descriptor the bridge registers.
export "src/runtime/cursor_plugin_descriptor.dart";
