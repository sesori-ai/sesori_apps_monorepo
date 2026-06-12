abstract class RuntimeOwnershipRepository<R> {
  Future<List<R>> readAll();

  Future<R?> readByOwnerSessionId({required String ownerSessionId});

  Future<void> upsert({required R record});

  Future<void> deleteByOwnerSessionId({required String ownerSessionId});
}
