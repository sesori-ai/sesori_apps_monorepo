/// Read side of "this plugin currently has a live generation", owned by the
/// bridge.
///
/// A managed-runtime install can run while the plugin is started on an older
/// managed version that is still supported, so the post-install sweep must not
/// delete the directory the running executable was launched from. The
/// installer reads this at sweep time — never caches it — and leaves a
/// still-used version directory for a later install to reclaim.
///
/// Like `StartAbortSignal`, this is bridge-owned live state handed to plugin
/// code as a narrow read-only fact rather than as a raw callback.
abstract class const RuntimeInUseSignal() {
  /// A signal for callers with no generation to protect (tests, tools).
  static const RuntimeInUseSignal never = _NeverInUseSignal();

  /// Whether the plugin has a live or starting generation. Cheap to poll.
  bool get isInUse;
}

final class const _NeverInUseSignal() implements RuntimeInUseSignal {
  @override
  bool get isInUse => false;
}
