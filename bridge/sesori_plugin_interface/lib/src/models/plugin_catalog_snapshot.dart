import "package:meta/meta.dart";

import "plugin_project.dart";
import "plugin_session.dart";

/// Complete metadata-only catalog for one plugin, grouped by project family.
@immutable
final class const PluginCatalogSnapshot({required final List<PluginProjectCatalogSnapshot> projects});

/// One project and every root/descendant session belonging to that project.
@immutable
final class const PluginProjectCatalogSnapshot({
  required final PluginProject project,
  required final List<PluginSession> sessions,
});

/// Cooperative cancellation visible to pre-start catalog implementations.
abstract interface class PluginCatalogCancellationSignal() {
  bool get isCancelled;
}

sealed class const PluginCatalogSnapshotResult();

final class const PluginCatalogSnapshotAvailable({required final PluginCatalogSnapshot snapshot})
    extends PluginCatalogSnapshotResult;

/// Snapshot source is unsupported, absent, or cannot be identified safely.
final class const PluginCatalogSnapshotUnavailable() extends PluginCatalogSnapshotResult;
