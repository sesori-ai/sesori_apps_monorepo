import 'dart:convert';
import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:path/path.dart' as path;
import 'package:sesori_shared/sesori_shared.dart';

import 'restricted_file_writer.dart';

part 'token.freezed.dart';
part 'token.g.dart';

/// TokenData holds authentication tokens for the Sesori Bridge.
///
/// No generated `toString`, so the tokens can never reach a log line.
@Freezed(fromJson: true, toJson: true, copyWith: false, toStringOverride: false)
sealed class TokenData with _$TokenData {
  // ignore: invalid_annotation_target, Freezed forwards this to the generated class.
  @JsonSerializable(checked: true)
  factory({
    required String accessToken,
    required String refreshToken,
    @authProviderConverter required AuthProvider lastProvider,
  }) = _TokenData;

  /// Throws [TokenDataFormatException] for any token file that is not valid
  /// token data, such as one written before `lastProvider` existed.
  factory fromJson(Map<String, dynamic> json) {
    try {
      return _$TokenDataFromJson(json);
    } on CheckedFromJsonException catch (error, stackTrace) {
      Error.throwWithStackTrace(TokenDataFormatException(innerError: error), stackTrace);
    }
  }
}

/// A token file that does not hold valid token data. Callers recover from it
/// like any other [FormatException] by asking the user to log in again.
final class const TokenDataFormatException({required final CheckedFromJsonException innerError})
    implements FormatException {
  @override
  String get message => "Invalid token data: $innerError";

  @override
  Object? get source => null;

  @override
  int? get offset => null;

  @override
  String toString() => "TokenDataFormatException: $message";
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
