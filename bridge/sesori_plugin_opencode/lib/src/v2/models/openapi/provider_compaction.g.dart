// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
abstract interface class ProviderCompaction {
  const ProviderCompaction();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory ProviderCompaction.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "summary":
        return ProviderCompactionSummary.fromJson(map);
      case "native":
        return ProviderCompactionNative.fromJson(map);
      default:
        return ProviderCompactionUnknown(raw: map);
    }
  }
}

@immutable
class ProviderCompactionSummary implements ProviderCompaction {
  const ProviderCompactionSummary();

  // ignore: avoid_unused_constructor_parameters
  factory ProviderCompactionSummary.fromJson(Map<String, dynamic> json) {
    return const ProviderCompactionSummary();
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "summary",
    };
  }

}


@immutable
class ProviderCompactionNative implements ProviderCompaction {
  const ProviderCompactionNative();

  // ignore: avoid_unused_constructor_parameters
  factory ProviderCompactionNative.fromJson(Map<String, dynamic> json) {
    return const ProviderCompactionNative();
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "native",
    };
  }

}


/// Fallback variant for an unrecognized [ProviderCompaction] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class ProviderCompactionUnknown implements ProviderCompaction {
  const ProviderCompactionUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderCompactionUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
