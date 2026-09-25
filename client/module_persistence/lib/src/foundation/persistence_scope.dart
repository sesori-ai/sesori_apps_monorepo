/// Stable namespaces shared by the database, cipher and native master item.
/// Each client shell selects one scope for its complete persistence graph.
enum PersistenceScope({
  required final String storageId,
  required final String databaseFileName,
  required final String masterKeyStorageKey,
}) {
  development(
    storageId: "development",
    databaseFileName: "client-persistence-development.sqlite",
    masterKeyStorageKey: "client-master-key-v1-development",
  ),
  production(
    storageId: "production",
    databaseFileName: "client-persistence-production.sqlite",
    masterKeyStorageKey: "client-master-key-v1-production",
  );

  /// Separate from legacy per-value storage, including during an interrupted import.
  static const masterKeyNamespace = "com.sesori.client.persistence";
}
