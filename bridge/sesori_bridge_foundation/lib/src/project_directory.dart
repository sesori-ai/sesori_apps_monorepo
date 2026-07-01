import "package:path/path.dart" as p;

/// Canonical equivalence key for a project directory: absolute + normalized so
/// trailing separators and `.`/`..` segments collapse, and differently-spelled
/// paths to the same directory map to one project.
///
/// The bridge uses this as a bridge-derived project's canonical id, so a
/// derive-style plugin MUST resolve its sessions' directories through the same
/// function — otherwise the project id the bridge hands back stops matching the
/// plugin's `getSessions` filter. (Plugin cwds are already absolute, so
/// `absolute` is defensive; it also preserves drive roots like `C:\` on
/// Windows.)
String normalizeProjectDirectory({required String directory}) =>
    p.normalize(p.absolute(directory));
