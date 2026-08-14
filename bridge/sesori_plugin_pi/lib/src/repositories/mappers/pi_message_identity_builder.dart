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

  PiMessageIdentitySnapshot snapshot() => PiMessageIdentitySnapshot._(Map.unmodifiable(_ordinals));

  void replaceHydrated({
    required PiMessageIdentityBuilder other,
    required PiMessageIdentitySnapshot since,
  }) {
    final merged = Map<String, int>.of(other._ordinals);
    for (final MapEntry(:key, :value) in _ordinals.entries) {
      final allocationsSinceRead = value - (since._ordinals[key] ?? 0);
      if (allocationsSinceRead > 0) {
        merged[key] = (merged[key] ?? 0) + allocationsSinceRead;
      }
    }
    _ordinals
      ..clear()
      ..addAll(merged);
  }

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

final class PiMessageIdentitySnapshot._(final Map<String, int> _ordinals);
