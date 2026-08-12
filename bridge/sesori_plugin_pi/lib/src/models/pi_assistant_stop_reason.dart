/// A terminal reason emitted by Pi's assistant stream.
enum PiAssistantStopReason {
  pending("pending"),
  stop("stop"),
  length("length"),
  toolUse("toolUse"),
  error("error"),
  aborted("aborted"),
  deferred("deferred");

  PiAssistantStopReason(this.wireValue);

  final String wireValue;

  static PiAssistantStopReason? tryParse({required String? value}) {
    for (final reason in values) {
      if (reason.wireValue == value) return reason;
    }
    return null;
  }
}
