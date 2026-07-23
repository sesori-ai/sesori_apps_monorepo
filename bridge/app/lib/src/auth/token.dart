import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
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

String tokenPath({required String dataDirectory}) => path.join(dataDirectory, 'token.json');

String bridgeIdPath({required String dataDirectory}) => path.join(dataDirectory, 'bridge_id');

/// Reads the bridge id persisted by an older bridge inside `token.json`.
///
/// Earlier versions stored the server-minted bridge id alongside the tokens.
/// It now lives in its own file, so this one-shot reader lets a freshly
/// upgraded bridge adopt the legacy id once instead of re-registering and
/// minting a duplicate entry. Returns null when the token file is absent,
/// corrupt, or has no `bridgeId` key.
// COMPATIBILITY 2026-06-30 (v1.3.0): Old installs persist bridgeId inside token.json. Remove this reader with BridgeIdMigrationService once those installs are unsupported.
Future<String?> readLegacyBridgeId({required String dataDirectory}) async {
  final file = File(tokenPath(dataDirectory: dataDirectory));

  try {
    final json = jsonDecodeMap(await file.readAsString());
    final bridgeId = json['bridgeId'];
    return bridgeId is String ? bridgeId : null;
  } on PathNotFoundException {
    // No legacy token file — nothing to adopt. This is the expected path on a
    // fresh install and in supervised mode, so it is not worth logging.
    return null;
  } on Object catch (error, stackTrace) {
    // A corrupt or unexpectedly-shaped legacy token file (FileSystemException,
    // FormatException, or a TypeError from a non-map root) must not crash
    // startup — skip adoption and let registration mint a fresh id.
    Log.w("Could not read legacy bridge id; skipping adoption", error, stackTrace);
    return null;
  }
}

/// Saves the token data to the token file.
/// Creates the directory structure if it doesn't exist.
Future<void> saveTokens({required TokenData data, required String dataDirectory}) async {
  final filePath = tokenPath(dataDirectory: dataDirectory);
  final dir = Directory(filePath).parent;

  // Create directory with restricted permissions (0o700 on Unix)
  await dir.create(recursive: true);
  if (!Platform.isWindows) {
    await Process.run('chmod', ['700', dir.path]);
  }

  // Convert to JSON with indentation
  final formatted = const JsonEncoder.withIndent('  ').convert(data.toJson());

  // Write file then restrict permissions (0o600 on Unix)
  await File(filePath).writeAsString(formatted);
  if (!Platform.isWindows) {
    await Process.run('chmod', ['600', filePath]);
  }
}

/// Loads the token data from the token file.
/// Throws FileSystemException if the file does not exist.
Future<TokenData> loadTokens({required String dataDirectory}) async {
  final file = File(tokenPath(dataDirectory: dataDirectory));

  try {
    final content = await file.readAsString();

    return TokenData.fromJson(jsonDecodeMap(content));
  } on FileSystemException {
    rethrow;
  }
}

/// Clears the token file by deleting it.
/// Does not throw an error if the file does not exist.
Future<void> clearTokens({required String dataDirectory}) async {
  final file = File(tokenPath(dataDirectory: dataDirectory));

  if (file.existsSync()) {
    await file.delete();
  }
}
