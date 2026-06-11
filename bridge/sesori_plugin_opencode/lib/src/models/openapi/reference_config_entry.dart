// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
abstract interface class ReferenceConfigEntry {
  const ReferenceConfigEntry();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory ReferenceConfigEntry.fromJson(Object json) {
    if (json is String) {
      return ReferenceConfigEntry00Inline.fromJson(json);
    }
    if (json is Map<String, dynamic> && json.containsKey("repository")) {
      return ReferenceConfigEntry01Inline.fromJson(json);
    }
    if (json is Map<String, dynamic> && json.containsKey("path")) {
      return ReferenceConfigEntry02Inline.fromJson(json);
    }
    return ReferenceConfigEntryUnknown(raw: json);
  }
}

@immutable
class ReferenceConfigEntry00Inline implements ReferenceConfigEntry {
  const ReferenceConfigEntry00Inline({required this.value});
  factory ReferenceConfigEntry00Inline.fromJson(String json) {
    return ReferenceConfigEntry00Inline(value: json);
  }
  @override
  Object? toJson() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceConfigEntry00Inline && other.value == value);

  @override
  int get hashCode => value.hashCode;

  final String value;
}


@immutable
class ReferenceConfigEntry01Inline implements ReferenceConfigEntry {
  const ReferenceConfigEntry01Inline({
    required this.repository,
    this.branch,
  });

  factory ReferenceConfigEntry01Inline.fromJson(Map<String, dynamic> json) {
    return ReferenceConfigEntry01Inline(
      repository: json["repository"] as String,
      branch: json["branch"] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "repository": repository,
      "branch": ?branch,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceConfigEntry01Inline &&
          other.repository == repository &&
          other.branch == branch);

  @override
  int get hashCode => Object.hash(repository, branch);

  final String repository;
  final String? branch;
}


@immutable
class ReferenceConfigEntry02Inline implements ReferenceConfigEntry {
  const ReferenceConfigEntry02Inline({
    required this.path,
  });

  factory ReferenceConfigEntry02Inline.fromJson(Map<String, dynamic> json) {
    return ReferenceConfigEntry02Inline(
      path: json["path"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "path": path,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceConfigEntry02Inline &&
          other.path == path);

  @override
  int get hashCode => path.hashCode;

  final String path;
}


/// Fallback variant for an unrecognized [ReferenceConfigEntry] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class ReferenceConfigEntryUnknown implements ReferenceConfigEntry {
  const ReferenceConfigEntryUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReferenceConfigEntryUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}
