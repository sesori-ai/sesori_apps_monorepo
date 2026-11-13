// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
abstract interface class ProviderCacheWarming {
  const ProviderCacheWarming();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory ProviderCacheWarming.fromJson(Object json) {
    if (json is Map<String, dynamic>) {
      return ProviderCacheWarming00Inline.fromJson(json);
    }
    return ProviderCacheWarmingUnknown(raw: json);
  }
}

@immutable
class ProviderCacheWarming00Inline implements ProviderCacheWarming {
  const ProviderCacheWarming00Inline({
    required this.interval,
    required this.duration,
  });

  factory ProviderCacheWarming00Inline.fromJson(Map<String, dynamic> json) {
    return ProviderCacheWarming00Inline(
      interval: json["interval"] as String?,
      duration: json["duration"] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "interval": ?interval,
      "duration": ?duration,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProviderCacheWarming00Inline copyWith({
    String? interval,
    String? duration,
  }) {
    return ProviderCacheWarming00Inline(
      interval: interval ?? this.interval,
      duration: duration ?? this.duration,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderCacheWarming00Inline && other.interval == interval && other.duration == duration);

  @override
  int get hashCode => Object.hash(interval, duration);

  final String? interval;
  final String? duration;
}

/// Fallback variant for an unrecognized [ProviderCacheWarming] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class ProviderCacheWarmingUnknown implements ProviderCacheWarming {
  const ProviderCacheWarmingUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderCacheWarmingUnknown && const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
