/// Whether a bridge keeps its computer awake: the stored choice, and for an
/// "on" choice, whether the operating system actually granted the wake lock.
enum SleepPreventionStatus() {
  /// The computer may sleep.
  off,

  /// The bridge holds a wake lock.
  awake,

  /// The choice is on, but the bridge could not get or keep a wake lock, so
  /// the computer can still sleep.
  failed,

  /// A status this build does not know.
  unknown,
}
