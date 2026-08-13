import "dart:typed_data";

final class AttachmentThumbnailMetadata {
  final String key;
  final int sizeBytes;
  final DateTime modifiedAt;

  const AttachmentThumbnailMetadata({
    required this.key,
    required this.sizeBytes,
    required this.modifiedAt,
  });
}

abstract interface class AttachmentThumbnailStorage {
  Future<Uint8List?> read({required String scope, required String key});

  Future<void> write({
    required String scope,
    required String key,
    required Uint8List bytes,
  });

  Future<List<AttachmentThumbnailMetadata>> listMetadata({required String scope});

  Future<void> delete({required String scope, required String key});

  Future<void> deleteScope({required String scope});
}
