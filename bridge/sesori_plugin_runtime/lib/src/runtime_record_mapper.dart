/// Maps a plugin-owned runtime record to and from its frozen persistence contract.
///
/// This is the byte-compatibility seam for managed plugin runtimes. At PR 11 the
/// OpenCode plugin supplies its existing Freezed ownership model verbatim through
/// this seam, writing byte-compatible JSON to the frozen legacy path.
abstract class RuntimeRecordMapper<R> {
  Map<String, dynamic> toJson({required R record});

  R fromJson({required Map<String, dynamic> json});

  String ownerSessionIdOf({required R record});

  int runtimePidOf({required R record});

  String? runtimeStartMarkerOf({required R record});

  String? runtimeExecutablePathOf({required R record});

  /// Full command line the runtime was spawned with, for example command plus
  /// args joined with single spaces. Used for identity matching when process
  /// start markers are present.
  ///
  /// Non-null by contract: a managed-runtime record must persist enough to
  /// reconstruct its spawn command line (the frozen OpenCode schema requires
  /// command and args). A nullable surface here would force the matcher to
  /// choose between leaking a live child (null never matches) or killing a
  /// recycled pid (null always matches).
  String runtimeCommandLineOf({required R record});

  int bridgePidOf({required R record});

  String? bridgeStartMarkerOf({required R record});

  R markStopping({required R record});
}
