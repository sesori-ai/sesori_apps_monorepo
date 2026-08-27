import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sesori_shared/sesori_shared.dart';

import '../foundation/restricted_file_writer.dart';

/// TokenData holds authentication tokens for the Sesori Bridge.
class TokenData({
  required final String accessToken,
  required final String refreshToken,
  required final AuthProvider lastProvider,
}) {
  /// Creates a TokenData instance from a JSON map.
  factory fromJson(Map<String, dynamic> json) {
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

/// Saves the token data to the token file, creating the data directory (0700)
/// and the file (0600) with restricted permissions on Unix.
Future<void> saveTokens({
  required TokenData data,
  required String dataDirectory,
  required RestrictedFileWriter writeRestrictedFile,
}) {
  return writeRestrictedFile(
    filePath: tokenPath(dataDirectory: dataDirectory),
    contents: const JsonEncoder.withIndent('  ').convert(data.toJson()),
  );
}

/// Loads the token data from the token file.
/// Throws FileSystemException if the file does not exist.
Future<TokenData> loadTokens({required String dataDirectory}) async {
  final file = File(tokenPath(dataDirectory: dataDirectory));

  final content = await file.readAsString();

  return TokenData.fromJson(jsonDecodeMap(content));
}

/// Clears the token file by deleting it.
/// Does not throw an error if the file does not exist.
Future<void> clearTokens({required String dataDirectory}) async {
  final file = File(tokenPath(dataDirectory: dataDirectory));

  if (file.existsSync()) {
    await file.delete();
  }
}
