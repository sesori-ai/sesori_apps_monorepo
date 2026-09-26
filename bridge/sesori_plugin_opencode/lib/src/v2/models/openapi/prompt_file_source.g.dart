// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
abstract interface class PromptFileSource {
  const PromptFileSource();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory PromptFileSource.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "inline":
        return PromptFileSourceInline.fromJson(map);
      case "uri":
        return PromptFileSourceUri.fromJson(map);
      default:
        return PromptFileSourceUnknown(raw: map);
    }
  }
}

@immutable
class PromptFileSourceInline implements PromptFileSource {
  const PromptFileSourceInline();

  // ignore: avoid_unused_constructor_parameters
  factory PromptFileSourceInline.fromJson(Map<String, dynamic> json) {
    return const PromptFileSourceInline();
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "inline",
    };
  }

}


@immutable
class PromptFileSourceUri implements PromptFileSource {
  const PromptFileSourceUri({
    required this.uri,
  });

  factory PromptFileSourceUri.fromJson(Map<String, dynamic> json) {
    return PromptFileSourceUri(
      uri: json["uri"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "uri",
      "uri": uri,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  PromptFileSourceUri copyWith({
    String? uri,
  }) {
    return PromptFileSourceUri(
      uri: uri ?? this.uri,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptFileSourceUri &&
          other.uri == uri);

  @override
  int get hashCode => uri.hashCode;

  final String uri;
}


/// Fallback variant for an unrecognized [PromptFileSource] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class PromptFileSourceUnknown implements PromptFileSource {
  const PromptFileSourceUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PromptFileSourceUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
