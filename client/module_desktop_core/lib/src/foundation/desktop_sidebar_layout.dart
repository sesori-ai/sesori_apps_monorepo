import "package:freezed_annotation/freezed_annotation.dart";

part "desktop_sidebar_layout.freezed.dart";
part "desktop_sidebar_layout.g.dart";

/// Desktop-only preferences; automatic narrow-window collapse is never stored.
@Freezed()
sealed class DesktopSidebarLayout with _$DesktopSidebarLayout {
  const factory({
    @Default(260) double width,
    @Default(false) bool collapsed,
  }) = _DesktopSidebarLayout;

  factory fromJson(Map<String, dynamic> json) => _$DesktopSidebarLayoutFromJson(json);
}
