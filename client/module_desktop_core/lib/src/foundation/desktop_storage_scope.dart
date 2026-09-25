/// Stable namespaces shared by the database, cipher and native master item.
/// The desktop shell selects one scope for the complete persistence graph.
enum DesktopStorageScope({
  required final String storageId,
  required final String databaseFileName,
  required final String masterKeyStorageKey,
}) {
  development(
    storageId: "development",
    databaseFileName: "desktop-persistence-development.sqlite",
    masterKeyStorageKey: "desktop-master-key-v1-development",
  ),
  production(
    storageId: "production",
    databaseFileName: "desktop-persistence-production.sqlite",
    masterKeyStorageKey: "desktop-master-key-v1-production",
  ),
}
