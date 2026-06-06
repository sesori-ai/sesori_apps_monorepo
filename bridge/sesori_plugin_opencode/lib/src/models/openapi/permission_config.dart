// GENERATED FILE - DO NOT EDIT BY HAND


abstract interface class PermissionConfig {
  const PermissionConfig();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory PermissionConfig.fromJson(Map<String, dynamic> json) {
    final discriminator = json["type"];
    switch (discriminator) {
      // inline variant skipped: PermissionConfig
      default:
        throw FormatException('Unknown PermissionConfig value: $discriminator');
    }
  }
}
