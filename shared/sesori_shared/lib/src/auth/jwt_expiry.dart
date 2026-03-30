import "dart:convert";

/// Parses a JWT token and extracts the expiry time from the `exp` claim.
///
/// Returns a [DateTime] in UTC if the token is valid and contains an `exp` claim,
/// or `null` if the token is invalid or missing the `exp` claim.
///
/// The function never throws — all errors are caught and return `null`.
DateTime? parseJwtExpiry(String token) {
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
    // ignore: no_slop_linter/avoid_as_cast, no_slop_linter/avoid_dynamic_type
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    final exp = json["exp"];

    if (exp is! int) return null;

    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}
