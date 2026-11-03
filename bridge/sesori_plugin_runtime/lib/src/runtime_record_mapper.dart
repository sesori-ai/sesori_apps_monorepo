/// Maps a plugin-owned runtime record to and from its frozen persistence contract.
///
/// Keeps managed-runtime supervision generic while each plugin owns its frozen
/// persistence schema.
abstract class RuntimeRecordMapper<R>() {
  Map<String, dynamic> toJson({required R record});

  R fromJson({required Map<String, dynamic> json});

  String ownerSessionIdOf({required R record});

  int runtimePidOf({required R record});

  String? runtimeStartMarkerOf({required R record});

  String? runtimeExecutablePathOf({required R record});

  /// The arguments the runtime was spawned with. When start markers are
  /// present, a live process matches the record only if its command line ends
  /// with these arguments. The executable part is not compared because it can
  /// change after spawn: an interpreter shim shows as `node <shim> <args>`, and
  /// a launcher can exec its native binary in the same pid.
  List<String> runtimeArgsOf({required R record});

  int bridgePidOf({required R record});

  String? bridgeStartMarkerOf({required R record});

  /// Returns a copy of [record] whose persisted lifecycle status is "ready".
  ///
  /// Written by the supervisor once a freshly spawned runtime has passed its
  /// first health probe. Symmetric with [markStopping].
  R markReady({required R record});

  R markStopping({required R record});
}
