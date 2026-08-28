import "dart:convert";

String? normalizeAttachmentBase64({required String encoded}) {
  try {
    return base64.normalize(encoded);
  } on FormatException {
    return null;
  }
}

String normalizeAttachmentMime({
  required String? raw,
  required String fallback,
  required int maxCharacters,
}) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return fallback;
  return String.fromCharCodes(trimmed.runes.take(maxCharacters)).toLowerCase();
}

String attachmentMimeEssence({required String mime}) => mime.split(";").first.trim();
