import "../models/plugin_message.dart";

/// Terse variant accessors for test assertions on a [PluginMessagePart].
///
/// Each one throws a [StateError] on the wrong variant, which fails the test
/// with the actual part type. Production code switches over the sealed
/// variants instead.
extension PluginMessagePartTestAccessors on PluginMessagePart {
  /// The text of a text or reasoning part.
  String get text {
    if (this case PluginMessagePartText(:final text) || PluginMessagePartReasoning(:final text)) return text;
    throw StateError("Expected textual message part, got ${type.name}");
  }

  String? get tool => asTool.tool;

  PluginToolState get state => asTool.state;

  PluginMessageAttachment get attachment => _variant<PluginMessagePartFile>().attachment;

  String get agentName => _variant<PluginMessagePartAgent>().agentName;

  int get attempt => _variant<PluginMessagePartRetry>().attempt;

  String get retryError => _variant<PluginMessagePartRetry>().retryError;

  PluginMessagePartTool get asTool => _variant<PluginMessagePartTool>();

  T _variant<T extends PluginMessagePart>() {
    if (this case final T part) return part;
    throw StateError("Expected ${T.toString()}, got ${type.name}");
  }
}
