/// Closed attribution outcomes that a platform sink may report.
///
/// Events with a [claimKey] are sent at most once per installation; the key
/// names the persisted claim marker. Events without one repeat freely.
enum AttributionEvent({required final String? claimKey}) {
  accountCreated(claimKey: null),
  accountLogin(claimKey: null),
  bridgePaired(claimKey: "bridge_paired_v1"),
  firstSessionRun(claimKey: "first_session_run_v1");

  bool get isOneShot => claimKey != null;
}
