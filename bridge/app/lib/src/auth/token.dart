import 'dart:convert';
import 'dart:io';

import 'package:sesori_shared/sesori_shared.dart';

import 'auth_provider.dart';

/// TokenData holds authentication tokens for the Sesori Bridge.
class TokenData {
  final String accessToken;
  final String refreshToken;
  final String? bridgeToken;
  final AuthProvider? lastProvider;

  TokenData({
    required this.accessToken,
    required this.refreshToken,
    this.bridgeToken,
    this.lastProvider,
  });

  /// Creates a TokenData instance from a JSON map.
  factory TokenData.fromJson(Map<String, dynamic> json) {
    return TokenData(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      bridgeToken: json['bridgeToken'] as String?,
      lastProvider: json['lastProvider'] != null
          ? AuthProvider.values
              .where((p) => p.name == json['lastProvider'])
              .firstOrNull
          : null,
    );
  }

  /// Converts the TokenData instance to a JSON map.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
    if (bridgeToken != null) {
      json['bridgeToken'] = bridgeToken;
    }
    if (lastProvider != null) {
      json['lastProvider'] = lastProvider!.name;
    }
    return json;
  }
}

/// Returns the path to the token file: ~/.config/sesori-bridge/token.json
String tokenPath() {
  final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (homeDir == null) {
    throw StateError('Unable to determine home directory');
  }
  return '$homeDir/.config/sesori-bridge/token.json';
}

/// Saves the token data to the token file.
/// Creates the directory structure if it doesn't exist.
Future<void> saveTokens(TokenData data) async {
  final path = tokenPath();
  final dir = Directory(path).parent;

  // Create directory with restricted permissions (0o700 on Unix)
  await dir.create(recursive: true);
  if (!Platform.isWindows) {
    await Process.run('chmod', ['700', dir.path]);
  }

  // Convert to JSON with indentation
  final formatted = const JsonEncoder.withIndent('  ').convert(data.toJson());

  // Write file then restrict permissions (0o600 on Unix)
  await File(path).writeAsString(formatted);
  if (!Platform.isWindows) {
    await Process.run('chmod', ['600', path]);
  }
}

/// Loads the token data from the token file.
/// Throws FileSystemException if the file does not exist.
Future<TokenData> loadTokens() async {
  final path = tokenPath();
  final file = File(path);

  try {
    final content = await file.readAsString();

    return TokenData.fromJson(jsonDecodeMap(content));
  } on FileSystemException {
    rethrow;
  }
}

/// Clears the token file by deleting it.
/// Does not throw an error if the file does not exist.
Future<void> clearTokens() async {
  final path = tokenPath();
  final file = File(path);

  try {
    await file.delete();
  } on FileSystemException catch (e) {
    // Ignore "file not found" errors
    if (!e.message.contains('No such file or directory')) {
      rethrow;
    }
  }
}
