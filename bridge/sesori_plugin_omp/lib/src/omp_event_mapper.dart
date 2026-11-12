import "package:acp_plugin/acp_plugin.dart";

/// Oh My Pi's ACP mapping. OMP sends its own tool name as a top-level `name`
/// on `tool_call` (outside the ACP schema, from 18.18.8); its `kind` buckets
/// task, wait and ask as `other`, so the name labels the card instead.
class OmpEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
}) extends AcpEventMapper {
  @override
  String? toolNameForToolUpdate({required Map<String, dynamic> update}) {
    final name = update["name"];
    return name is String && name.isNotEmpty ? name : null;
  }
}
