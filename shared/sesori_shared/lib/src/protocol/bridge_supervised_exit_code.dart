/// Cross-product process exit contract between a supervised bridge and its
/// desktop process supervisor.
///
/// Any code not represented here is an ordinary crash. The desktop may still
/// apply crash policy to a represented outcome such as [controlChannelLost],
/// but both products share one authoritative numeric meaning.
enum BridgeSupervisedExitCode({required final int code}) {
  /// A requested shutdown completed and the desktop must remain Off.
  cleanStop(code: 0),

  /// The local control-channel owner disappeared past its grace period.
  controlChannelLost(code: 1),

  /// An intentional restart handoff requires an immediate replacement helper.
  restart(code: 86),

  /// The GUI could not supply bootstrap authentication.
  authRequired(code: 87),

  /// Another same-machine bridge retained ownership.
  bridgeContention(code: 88);

  static BridgeSupervisedExitCode? fromCode({required int code}) {
    for (final BridgeSupervisedExitCode value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return null;
  }
}
