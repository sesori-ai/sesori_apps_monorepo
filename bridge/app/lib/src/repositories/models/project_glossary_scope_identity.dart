/// Bridge-private identity material used to derive an opaque glossary scope.
/// Raw origins and paths never cross the bridge boundary.
sealed class const ProjectGlossaryScopeIdentity();

final class const RepositoryProjectGlossaryIdentity({required final String canonicalOrigin})
    extends ProjectGlossaryScopeIdentity;

final class const BridgeLocalProjectGlossaryIdentity({required final String normalizedAbsolutePath})
    extends ProjectGlossaryScopeIdentity;
