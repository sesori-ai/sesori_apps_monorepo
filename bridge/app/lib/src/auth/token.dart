import 'dart:convert';
import 'dart:io';

import 'package:sesori_shared/sesori_shared.dart';

/// TokenData holds authentication tokens for the Sesori Bridge.
class TokenData {
  final String accessToken;
  final String refreshToken;
  final String? bridgeToken;
  final AuthProvider lastProvider;

  TokenData({
    required this.accessToken,
    required this.refreshToken,
    this.bridgeToken,
    required this.lastProvider,
  });

  /// Creates a TokenData instance from a JSON map.
  factory TokenData.fromJson(Map<String, dynamic> json) {
    final providerName = json['lastProvider'] as String?;
    if (providerName == null) {
      throw const FormatException("lastProvider missing in token data");
    }
    final provider = AuthProvider.values
        .where((p) => p.name == providerName)
        .firstOrNull;
    if (provider == null) {
      throw FormatException("invalid lastProvider: $providerName");
    }

    return TokenData(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      bridgeToken: json['bridgeToken'] as String?,
      lastProvider: provider,
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
    json['lastProvider'] = lastProvider.name;
    return json;
  }
}

String tokenPath() {
  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) {
      throw StateError('LOCALAPPDATA environment variable not set');
    }
    return '$localAppData/sesori/token.json';
  }
  final homeDir = Platform.environment['HOME'];
  if (homeDir == null || homeDir.isEmpty) {
    throw StateError('HOME environment variable not set');
  }
  return '$homeDir/.local/share/sesori/token.json';
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
