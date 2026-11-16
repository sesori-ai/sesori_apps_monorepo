/// Whether a session is between turns with nothing waiting on the user.
enum SessionQuietness() {
  /// No turn, retry, queued prompt, pending wake-up or busy sub-agent, and
  /// nothing waiting on the user. Also a session whose backend is not running.
  quiet,

  /// A turn, retry, queued prompt, pending wake-up or sub-agent is running.
  working,

  /// A question, permission or form waits on the user.
  awaitingUser,

  /// The session or its backend state could not be read.
  unknown,
}
