// GENERATED FILE - DO NOT EDIT BY HAND


abstract interface class MCPStatus {
  const MCPStatus();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory MCPStatus.fromJson(Map<String, dynamic> json) {
    final discriminator = json["type"];
    switch (discriminator) {
      default:
        throw FormatException('Unknown MCPStatus value: $discriminator');
    }
  }
}
