import "package:path/path.dart" as p;

/// Canonical equivalence key for a project directory: absolute + normalized so
/// trailing separators and `.`/`..` segments collapse, and differently-spelled
/// paths to the same directory map to one project.
///
/// The bridge uses this as the default id for a bridge-owned aggregate project,
/// so a plugin that groups sessions by directory MUST resolve those directories
/// through the same function. (Plugin cwds are already absolute, so `absolute`
/// is defensive; it also preserves drive roots like `C:\` on Windows.)
String normalizeProjectDirectory({required String directory}) => p.normalize(p.absolute(directory));
