// GENERATED FILE - DO NOT EDIT BY HAND


abstract interface class SessionStatus {
  const SessionStatus();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory SessionStatus.fromJson(Map<String, dynamic> json) {
    final discriminator = json["type"];
    switch (discriminator) {
      // inline variant skipped: SessionStatus
      // inline variant skipped: SessionStatus
      // inline variant skipped: SessionStatus
      default:
        throw FormatException('Unknown SessionStatus value: $discriminator');
    }
  }
}
