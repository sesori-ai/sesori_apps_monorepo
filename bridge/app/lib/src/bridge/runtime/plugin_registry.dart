import "package:codex_plugin/codex_plugin.dart" show CodexPluginDescriptor;
import "package:cursor_plugin/cursor_plugin.dart" show CursorPluginDescriptor;
import "package:opencode_plugin/opencode_plugin.dart" show OpenCodePluginDescriptor;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginDescriptor;

/// Every plugin this bridge build knows how to run.
///
/// Descriptors are const and side-effect free. Registration does not imply
/// setup readiness, eligibility, or a running backend generation.
const List<BridgePluginDescriptor> knownPlugins = [
  OpenCodePluginDescriptor(),
  CodexPluginDescriptor(),
  CursorPluginDescriptor(),
];
