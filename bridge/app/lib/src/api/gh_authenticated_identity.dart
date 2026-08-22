import "package:freezed_annotation/freezed_annotation.dart";

part "gh_authenticated_identity.freezed.dart";

@freezed
sealed class GhAuthenticatedIdentity with _$GhAuthenticatedIdentity {
  const factory({required String rawLogin}) = _GhAuthenticatedIdentity;
}
