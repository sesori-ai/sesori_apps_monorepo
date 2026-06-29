import 'dart:convert';
import 'dart:io';

import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;
import 'package:sesori_shared/sesori_shared.dart';

/// TokenData holds authentication tokens for the Sesori Bridge.
class TokenData {
  final String accessToken;
  final String refreshToken;
  final AuthProvider lastProvider;

  TokenData({
    required this.accessToken,
    required this.refreshToken,
    required this.lastProvider,
  });

  /// Creates a TokenData instance from a JSON map.
  factory TokenData.fromJson(Map<String, dynamic> json) {
    final providerName = json['lastProvider'] as String?;
    if (providerName == null) {
      throw const FormatException("lastProvider missing in token data");
    }
    final provider = AuthProvider.fromKey(providerName);
    if (provider == null) {
      throw FormatException("invalid lastProvider: $providerName");
    }

    return TokenData(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      lastProvider: provider,
    );
  }

  /// Converts the TokenData instance to a JSON map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'lastProvider': lastProvider.key,
    };
  }
}

String tokenPath() => '${sesoriDataDirectory()}/token.json';

String bridgeIdPath() => '${sesoriDataDirectory()}/bridge_id';

/// Reads the bridge id persisted by an older bridge inside `token.json`.
///
/// Earlier versions stored the server-minted bridge id alongside the tokens.
/// It now lives in its own file, so this one-shot reader lets a freshly
/// upgraded bridge adopt the legacy id once instead of re-registering and
/// minting a duplicate entry. Returns null when the token file is absent,
/// corrupt, or has no `bridgeId` key.
Future<String?> readLegacyBridgeId() async {
  final file = File(tokenPath());

  try {
    final json = jsonDecodeMap(await file.readAsString());
    return json['bridgeId'] as String?;
  } on PathNotFoundException {
    // No legacy token file — nothing to adopt. This is the expected path on a
    // fresh install and in supervised mode, so it is not worth logging.
    return null;
  } on FileSystemException catch (error) {
    Log.w("Could not read legacy bridge id; skipping adoption", error);
    return null;
  } on FormatException catch (error) {
    Log.w("Legacy token file is corrupt; skipping bridge-id adoption", error);
    return null;
  }
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

  if (file.existsSync()) {
    await file.delete();
  }
}
