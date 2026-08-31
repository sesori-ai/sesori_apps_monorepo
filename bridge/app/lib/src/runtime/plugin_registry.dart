import "package:claude_plugin/claude_plugin.dart" show ClaudePluginDescriptor;
import "package:codex_plugin/codex_plugin.dart" show CodexPluginDescriptor;
import "package:copilot_plugin/copilot_plugin.dart" show CopilotPluginDescriptor;
import "package:cursor_plugin/cursor_plugin.dart" show CursorPluginDescriptor;
import "package:deepseek_plugin/deepseek_plugin.dart" show DeepSeekPluginDescriptor;
import "package:grok_plugin/grok_plugin.dart" show GrokPluginDescriptor;
import "package:hermes_plugin/hermes_plugin.dart" show HermesPluginDescriptor;
import "package:omp_plugin/omp_plugin.dart" show OmpPluginDescriptor;
import "package:opencode_plugin/opencode_plugin.dart" show OpenCodePluginDescriptor;
import "package:pi_plugin/pi_plugin.dart" show PiPluginDescriptor;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginDescriptor;

/// Every plugin this bridge build knows how to run.
///
/// Descriptors are const and side-effect free. Registration does not imply
/// setup readiness, eligibility, or a running backend generation.
const OpenCodePluginDescriptor _openCodePlugin = OpenCodePluginDescriptor();

final List<BridgePluginDescriptor> knownPlugins = List.unmodifiable([
  _openCodePlugin,
  const CodexPluginDescriptor(),
  CopilotPluginDescriptor.production(),
  const CursorPluginDescriptor(),
  const ClaudePluginDescriptor(),
  const HermesPluginDescriptor(),
  PiPluginDescriptor.production(),
  OmpPluginDescriptor.production(),
  const DeepSeekPluginDescriptor(),
  const GrokPluginDescriptor(),
]);

String get openCodePluginId => _openCodePlugin.id;

/// Product-preferred default when OpenCode is selectable. Lifecycle policy
/// falls back to the first selectable registration when it is not.
String get preferredDefaultPluginId => _openCodePlugin.id;
