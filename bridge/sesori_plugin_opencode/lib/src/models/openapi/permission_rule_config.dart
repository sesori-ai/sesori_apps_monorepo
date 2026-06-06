// GENERATED FILE - DO NOT EDIT BY HAND


abstract interface class PermissionRuleConfig {
  const PermissionRuleConfig();

  /// Serialize the underlying variant. Variants must override this.
  Map<String, dynamic> toJson();

  factory PermissionRuleConfig.fromJson(Map<String, dynamic> json) {
    final discriminator = json["type"];
    switch (discriminator) {
      default:
        throw FormatException('Unknown PermissionRuleConfig value: $discriminator');
    }
  }
}
