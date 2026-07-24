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

/// Product-preferred default when OpenCode is selectable. Lifecycle policy
/// falls back to the first selectable registration when it is not.
String get preferredDefaultPluginId => const OpenCodePluginDescriptor().id;

/// TEMPORARY RELEASE GATE (2026-07-24): only OpenCode is approved for the next
/// synchronized App + Bridge release. Keep every descriptor registered so CLI
/// options and persisted settings remain known. Revert this gate immediately
/// after that release.
final Set<String> temporaryOpenCodeOnlyReleasePluginIds = Set<String>.unmodifiable({
  preferredDefaultPluginId,
});

Set<String> disabledPluginIdsForTemporaryOpenCodeOnlyRelease({
  required Set<String> configuredDisabledPluginIds,
}) {
  return Set<String>.unmodifiable({
    ...configuredDisabledPluginIds,
    for (final plugin in knownPlugins)
      if (!temporaryOpenCodeOnlyReleasePluginIds.contains(plugin.id)) plugin.id,
  });
}
