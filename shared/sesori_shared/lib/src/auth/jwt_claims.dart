import "dart:convert";

import "../../sesori_shared.dart" show jsonDecodeMap;

/// Parses a JWT token and extracts the expiry time from the `exp` claim.
///
/// Returns a [DateTime] in UTC if the token is valid and contains an `exp` claim,
/// or `null` if the token is invalid or missing the `exp` claim.
///
/// The function never throws — all errors are caught and return `null`.
DateTime? parseJwtExpiry(String token) {
  final claims = _decodeJwtPayload(token);
  final exp = claims?["exp"];
  if (exp is! int) return null;
  try {
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  } catch (_) {
    // An exp outside DateTime's supported range (ArgumentError) is malformed
    // input — same null contract as any other undecodable token.
    return null;
  }
}

/// Parses a JWT token and extracts the auth identity from the `userId` claim
/// (the claim the Sesori auth server issues and the relay keys connections on).
///
/// Returns `null` if the token is malformed or the claim is absent or not a
/// String. The function never throws.
String? parseJwtUserId(String token) {
  final userId = _decodeJwtPayload(token)?["userId"];
  return userId is String ? userId : null;
}

/// Decodes the payload segment of a JWT into its claims map, or `null` when
/// the token is not a decodable three-segment JWT. Never throws.
// ignore: no_slop_linter/prefer_specific_type, JSON decoding
Map<String, dynamic>? _decodeJwtPayload(String token) {
  try {
    final parts = token.split(".");
    if (parts.length != 3) return null;

    String payload = parts[1];

    // Fix base64url padding
    switch (payload.length % 4) {
      case 2:
        payload = "$payload==";
      case 3:
        payload = "$payload=";
    }

    final decoded = utf8.decode(base64Url.decode(payload));
    return jsonDecodeMap(decoded);
  } catch (_) {
    // Malformed input (not a JWT, bad base64, non-object JSON) is an expected
    // input class here — callers treat null as "no such claim".
    return null;
  }
}
