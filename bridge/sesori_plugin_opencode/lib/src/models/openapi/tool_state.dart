// GENERATED FILE - DO NOT EDIT BY HAND


abstract interface class ToolState {
  const ToolState();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory ToolState.fromJson(Map<String, dynamic> json) {
    final discriminator = json["type"];
    switch (discriminator) {
      default:
        throw FormatException('Unknown ToolState value: $discriminator');
    }
  }
}
