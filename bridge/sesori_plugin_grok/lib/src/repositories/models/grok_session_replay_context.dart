/// Immutable child-owned prompt context prepared for one Grok root replay.
/// Keys are exact native child session ids; absent prompts are not represented.
final class GrokSessionReplayContext({required Map<String, String> childPrompts}) {
  final Map<String, String> childPrompts = Map.unmodifiable(childPrompts);

  String? promptFor({required String childSessionId}) => childPrompts[childSessionId];
}
