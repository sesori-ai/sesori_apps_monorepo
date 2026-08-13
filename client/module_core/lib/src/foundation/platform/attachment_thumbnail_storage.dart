import "dart:typed_data";

final class const AttachmentThumbnailMetadata({
  required final String key,
  required final int sizeBytes,
  required final DateTime modifiedAt,
});

abstract interface class AttachmentThumbnailStorage() {
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
