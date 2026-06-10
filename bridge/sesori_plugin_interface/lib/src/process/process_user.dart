// ignore_for_file: unused_field

import "package:meta/meta.dart";

@immutable
class ProcessUser {
  final String _rawUser;
  final String _normalizedUser;

  const ProcessUser._({
    required String rawUser,
    required String normalizedUser,
  }) : _rawUser = rawUser,
       _normalizedUser = normalizedUser;

  static ProcessUser? fromRawUser(String? rawUser) {
    final trimmedRawUser = rawUser?.trim();
    if (trimmedRawUser == null || trimmedRawUser.isEmpty) return null;

    return ProcessUser._(
      rawUser: trimmedRawUser,
      normalizedUser: _normalizeUser(trimmedRawUser),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProcessUser) return false;
    return _normalizedUser == other._normalizedUser;
  }

  @override
  int get hashCode => _normalizedUser.hashCode;
}

String _normalizeUser(String user) {
  final backslashIndex = user.lastIndexOf(r'\');
  final normalized = backslashIndex >= 0 ? user.substring(backslashIndex + 1) : user;
  return normalized.toLowerCase();
}
