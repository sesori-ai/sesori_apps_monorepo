/// Native execution interruption semantics; shutdown retains the execution claim.
enum V2ExecutionInterruptReason() {
  user,
  shutdown,
  superseded,
  inactivity,
  unknown;

  static V2ExecutionInterruptReason fromJson(String value) =>
      values.where((reason) => reason.name == value).firstOrNull ?? unknown;

  String toJson() => name;
}
