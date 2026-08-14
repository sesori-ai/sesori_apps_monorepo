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
  final Map<String, int> _allocations = {};

  PiMessageIdentitySnapshot snapshot() => PiMessageIdentitySnapshot._(
    ordinals: Map.unmodifiable(_ordinals),
    allocations: Map.unmodifiable(_allocations),
  );

  void replaceHydrated({
    required PiMessageIdentityBuilder other,
    required PiMessageIdentitySnapshot since,
  }) {
    final merged = Map<String, int>.of(other._ordinals);
    for (final MapEntry(:key, :value) in _allocations.entries) {
      final allocationsSinceRead = value - (since._allocations[key] ?? 0);
      final replayGrowth = (other._ordinals[key] ?? 0) - (since._ordinals[key] ?? 0);
      final unpersistedAllocations = allocationsSinceRead - replayGrowth.clamp(0, allocationsSinceRead);
      if (unpersistedAllocations > 0) {
        merged[key] = (merged[key] ?? 0) + unpersistedAllocations;
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
    _allocations[key] = (_allocations[key] ?? 0) + 1;
    return "$pluginId:$sessionId:${role.segment}:$timestampPart:$ordinal";
  }
}

final class PiMessageIdentitySnapshot._({
  required final Map<String, int> ordinals,
  required final Map<String, int> allocations,
}) {
  final Map<String, int> _ordinals = ordinals;
  final Map<String, int> _allocations = allocations;
}
