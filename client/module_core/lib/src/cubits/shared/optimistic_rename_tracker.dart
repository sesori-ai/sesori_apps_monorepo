/// Per-entity bookkeeping for optimistic renames.
///
/// A rename sheet closes as soon as the user confirms, so several renames of
/// the same entity can be in flight at once and complete out of order. The
/// tracker keeps the newest confirmed value and the latest unresolved user
/// intent so the visible value never regresses to an older request:
///
/// - the visible value is the most recently begun rename until it fails;
/// - a success is confirmed only when it is newer than the current
///   confirmation, so an older success cannot overwrite a newer one;
/// - when the visible rename fails and others are still pending, the visible
///   value falls back to the newest pending request, or to the confirmation if
///   that is newer still.
///
/// Owning cubits instantiate one tracker per entity and keep entity maps,
/// repository calls and state projection to themselves. [confirmedValue] is
/// nullable because an entity may have no name before its first rename.
final class OptimisticRenameTracker({required String? confirmedValue}) {
  final Map<int, String> _pendingValues = {};
  int _visibleToken = 0;
  late String _visibleValue;
  int _confirmedToken = 0;
  String? _confirmedValue = confirmedValue;

  /// The value the UI shows while renames are unresolved.
  String get visibleValue => _visibleValue;

  /// The newest value the bridge accepted, or the original when none has.
  String? get confirmedValue => _confirmedValue;

  /// True once no rename is outstanding; the owner then drops this tracker.
  bool get isSettled => _pendingValues.isEmpty;

  void begin({required int token, required String value}) {
    _pendingValues[token] = value;
    _visibleToken = token;
    _visibleValue = value;
  }

  void complete({required int token, required String value, required bool succeeded}) {
    _pendingValues.remove(token);
    if (succeeded && token > _confirmedToken) {
      _confirmedToken = token;
      _confirmedValue = value;
    }
    if (!succeeded && token == _visibleToken && _pendingValues.isNotEmpty) {
      _selectLatestVisibleValue();
    }
  }

  void _selectLatestVisibleValue() {
    final firstPending = _pendingValues.entries.first;
    var latestPendingToken = firstPending.key;
    var latestPendingValue = firstPending.value;
    for (final MapEntry(:key, :value) in _pendingValues.entries.skip(1)) {
      if (key > latestPendingToken) {
        latestPendingToken = key;
        latestPendingValue = value;
      }
    }
    final confirmedValue = _confirmedValue;
    if (_confirmedToken > latestPendingToken && confirmedValue != null) {
      _visibleToken = _confirmedToken;
      _visibleValue = confirmedValue;
      return;
    }
    _visibleToken = latestPendingToken;
    _visibleValue = latestPendingValue;
  }
}
