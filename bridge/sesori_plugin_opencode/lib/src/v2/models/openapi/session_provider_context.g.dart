// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_provider_context_provenance.g.dart';

@immutable
class SessionProviderContext {
  const SessionProviderContext({
    required this.version,
    required this.provenance,
    required this.messages,
  });

  factory SessionProviderContext.fromJson(Map<String, dynamic> json) {
    return SessionProviderContext(
      version: (json["version"] as num).toDouble(),
      provenance: SessionProviderContextProvenance.fromJson(json["provenance"] as Map<String, dynamic>),
      messages: json["messages"] as Object,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "version": version,
      "provenance": provenance.toJson(),
      "messages": messages,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionProviderContext copyWith({
    double? version,
    SessionProviderContextProvenance? provenance,
    Object? messages,
  }) {
    return SessionProviderContext(
      version: version ?? this.version,
      provenance: provenance ?? this.provenance,
      messages: messages ?? this.messages,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionProviderContext &&
          other.version == version &&
          other.provenance == provenance &&
          const DeepCollectionEquality().equals(other.messages, messages));

  @override
  int get hashCode => Object.hash(version, provenance, const DeepCollectionEquality().hash(messages));

  final double version;
  final SessionProviderContextProvenance provenance;
  final Object messages;
}
