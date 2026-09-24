import "package:freezed_annotation/freezed_annotation.dart";

part "desktop_sidebar_layout.freezed.dart";
part "desktop_sidebar_layout.g.dart";

/// Desktop-only preferences; automatic narrow-window collapse is never stored.
@Freezed()
sealed class DesktopSidebarLayout with _$DesktopSidebarLayout {
  const factory({
    @Default(260) double width,
    @Default(false) bool collapsed,
    @Default({}) Set<String> collapsedProjectIds,

    /// Sessions the user marked unread on this desktop, each with its
    /// `time.updated` at that moment, oldest first. Activity leaves such a
    /// session alone until the agent moves that stamp.
    @Default({}) Map<String, int> deferredSessions,

    /// Section headers the user folded; a folded section hides its rows.
    @Default(false) bool activitySectionCollapsed,
    @Default(false) bool projectsSectionCollapsed,
  }) = _DesktopSidebarLayout;

  factory fromJson(Map<String, dynamic> json) => _$DesktopSidebarLayoutFromJson(json);
}
