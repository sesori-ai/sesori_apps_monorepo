import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// A complete canonical tool state ready for history or live presentation.
final class CodexProjectedTool {
  CodexProjectedTool({
    required this.canonicalId,
    required this.tool,
    required this.title,
    required this.status,
    required this.output,
    required List<PluginMessageAttachment> attachments,
  }) : attachments = List.unmodifiable(attachments);

  final String canonicalId;
  final String tool;
  final String? title;
  final PluginToolStatus status;
  final String? output;
  final List<PluginMessageAttachment> attachments;
}
