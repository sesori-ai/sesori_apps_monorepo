import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// A complete canonical tool state ready for history or live presentation.
final class CodexProjectedTool({
  required final String canonicalId,
  required final String tool,
  required final CodexToolPresentation presentation,
  required final String? title,
  required final PluginToolStatus status,
  required final String? output,
  required final PluginMessageTime? time,
  required List<PluginMessageAttachment> attachments,
}) {
  final List<PluginMessageAttachment> attachments = List.unmodifiable(attachments);
}

sealed class const CodexToolPresentation();

final class const CodexOrdinaryToolPresentation() extends CodexToolPresentation;

/// Spawn input and its child identity, enriched when Codex announces the child.
/// The spawn tool's completion is separate from that child's work lifecycle.
final class const CodexSubtaskPresentation({
  required final String? taskName,
  required final String? prompt,
  required final String agent,
  required final String? childSessionId,
}) extends CodexToolPresentation;
