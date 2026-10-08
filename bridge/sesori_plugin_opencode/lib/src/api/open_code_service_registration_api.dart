import "dart:io" as io;

import "package:freezed_annotation/freezed_annotation.dart" show CheckedFromJsonException;
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../models/open_code_service_registration.dart";

/// A registration file that exists but cannot be read or decoded. [message]
/// is privacy-safe; [cause] keeps the original error, whose own text can quote
/// the file (and so the service password) and must not be logged verbatim.
class const OpenCodeServiceRegistrationException({required final String message, required final Object cause})
    implements Exception {
  @override
  String toString() => "OpenCodeServiceRegistrationException: $message";
}

/// Layer-1 reader for OpenCode 2's shared-service registration file. It makes
/// no decisions: a missing file is `null`, anything unreadable or undecodable
/// throws [OpenCodeServiceRegistrationException].
class const OpenCodeServiceRegistrationApi() {
  Future<OpenCodeServiceRegistration?> read({required String filePath}) async {
    final String text;
    try {
      text = await io.File(filePath).readAsString();
    } on io.PathNotFoundException {
      return null;
    } on io.FileSystemException catch (error) {
      throw OpenCodeServiceRegistrationException(
        message: "cannot read $filePath (${error.osError?.message ?? error.message})",
        cause: error,
      );
    }
    try {
      return OpenCodeServiceRegistration.fromJson(jsonDecodeMap(text));
    } on FormatException catch (error) {
      throw OpenCodeServiceRegistrationException(message: "$filePath is not a JSON object", cause: error);
    } on CheckedFromJsonException catch (error) {
      throw OpenCodeServiceRegistrationException(
        message: "$filePath has an invalid '${error.key}' field",
        cause: error,
      );
    }
  }
}
