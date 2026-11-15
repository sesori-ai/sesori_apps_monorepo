/// Whether a session can ask side questions, and if not, why.
enum SideQuestionAvailability() {
  /// The bridge has the side-question routes and the session's harness
  /// answers side questions.
  available,

  /// The bridge is too old to have the side-question routes.
  bridgeUpdateRequired,

  /// The session's harness can't answer side questions.
  harnessUnsupported,

  /// Not known yet: the session has no plugin id, the plugin listing failed,
  /// or the listing doesn't name the session's harness.
  unresolved,
}
