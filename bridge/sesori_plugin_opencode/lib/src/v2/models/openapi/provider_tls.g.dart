// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.2 (c0ad18b402eb2827fc1ee71c171b1177b3fc02d1)

import 'package:meta/meta.dart';

@immutable
class ProviderTls {
  const ProviderTls({
    required this.cert,
    required this.key,
    required this.passphrase,
  });

  factory ProviderTls.fromJson(Map<String, dynamic> json) {
    return ProviderTls(
      cert: json["cert"] as String,
      key: json["key"] as String,
      passphrase: json["passphrase"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "cert": cert,
      "key": key,
      "passphrase": ?passphrase,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProviderTls copyWith({
    String? cert,
    String? key,
    String? passphrase,
  }) {
    return ProviderTls(
      cert: cert ?? this.cert,
      key: key ?? this.key,
      passphrase: passphrase ?? this.passphrase,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderTls &&
          other.cert == cert &&
          other.key == key &&
          other.passphrase == passphrase);

  @override
  int get hashCode => Object.hash(cert, key, passphrase);

  final String cert;
  final String key;
  final String? passphrase;
}
