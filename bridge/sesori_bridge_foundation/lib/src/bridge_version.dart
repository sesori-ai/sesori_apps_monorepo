/// The bridge release version, reported by `--version`, the health route,
/// the updater and the `clientInfo` the plugins send to their harnesses.
///
/// `make bump-version` (`tool/sync_versions.dart`) and
/// `bridge/app/tool/bump_version.dart` rewrite this line, so keep its shape.
const String bridgeVersion = '1.14.0';
