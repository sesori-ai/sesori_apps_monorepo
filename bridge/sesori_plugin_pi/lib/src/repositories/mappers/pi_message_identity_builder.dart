enum PiMessageIdentityRole(final String segment) {
  user("user"),
  assistant("assistant"),
  custom("custom"),
  bashExecution("bashExecution"),
  compaction("compaction");
}

final class PiMessageIdentityBuilder({
  required final String pluginId,
  required final String sessionId,
}) {
  static const String missingTimestampSentinel = "missing";
  static const String compactionTimestampSentinel = "compaction";
  static const String customMessageTimestampSentinel = "custom-message";

  final Map<String, int> _ordinals = {};

  String next({required PiMessageIdentityRole role, required int? timestamp}) {
    return _next(role: role, timestampPart: timestamp?.toString() ?? missingTimestampSentinel);
  }

  String nextCompaction() {
    return _next(role: PiMessageIdentityRole.compaction, timestampPart: compactionTimestampSentinel);
  }

  String nextTopLevelCustomMessage() {
    return _next(role: PiMessageIdentityRole.custom, timestampPart: customMessageTimestampSentinel);
  }

  String _next({required PiMessageIdentityRole role, required String timestampPart}) {
    final key = "${role.segment}\u0000$timestampPart";
    final ordinal = (_ordinals[key] ?? 0) + 1;
    _ordinals[key] = ordinal;
    return "$pluginId:$sessionId:${role.segment}:$timestampPart:$ordinal";
  }
}
