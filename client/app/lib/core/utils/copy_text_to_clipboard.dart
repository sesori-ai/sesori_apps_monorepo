import "package:flutter/services.dart";
import "package:sesori_dart_core/logging.dart";

Future<bool> copyTextToClipboard({required String text, required String operation}) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } on Object catch (error, stackTrace) {
    logw("Failed to copy $operation", error, stackTrace);
    return false;
  }
}
