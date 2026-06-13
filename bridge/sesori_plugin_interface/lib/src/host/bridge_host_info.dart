import "../process/process_identity.dart";

/// Identity facts about the bridge process hosting the plugin.
abstract class BridgeHostInfo {
  /// The identity of the bridge process itself.
  ProcessIdentity get identity;

  /// Stable identifier for this bridge run, used to scope ownership records
  /// (so a runtime started by this bridge can be told apart from one started
  /// by a previous, possibly crashed, bridge).
  String get ownerSessionId;

  /// Identities of the bridge processes this bridge replaced during startup
  /// (the user accepted terminating them, or they were reclaimed from a stale
  /// startup lock). Empty when no bridge was replaced.
  ///
  /// Stale-runtime cleanup is explicitly authorized to reclaim records owned
  /// by these bridges: a just-terminated owner can still look alive to a
  /// liveness probe (its PID lingers, or was reused without start markers —
  /// the Windows path), and sparing it would orphan the runtime it owned.
  List<ProcessIdentity> get terminatedBridgeIdentities;

  /// Whether the process [pid] is a *live sesori-bridge process* matching
  /// [startMarker].
  ///
  /// This is the authorization primitive for stale-runtime cleanup: a
  /// runtime whose recorded owner is still a live bridge must be spared;
  /// one whose owner is gone (or whose pid was reused by an unrelated
  /// process) may be cleaned up.
  ///
  /// Exposed as a capability rather than data on purpose — the strings and
  /// heuristics that classify a bridge process stay inside the bridge, free
  /// to evolve without breaking plugins. Marker matching: when either side
  /// has a start marker they must match; when both are absent (Windows
  /// records carry none) the marker check is conservatively accepted and the
  /// decision rests on the bridge-process classification alone — the caller
  /// supplies only a pid and marker, so unlike
  /// [ProcessIdentity.hasSameIdentityAs] there is no command line to fall
  /// back on. Conservative direction: a reused pid that happens to be
  /// another live bridge is spared (a possible orphan, which stale cleanup
  /// self-heals later) rather than killed.
  Future<bool> isLiveBridgeProcess({required int pid, required String? startMarker});
}
