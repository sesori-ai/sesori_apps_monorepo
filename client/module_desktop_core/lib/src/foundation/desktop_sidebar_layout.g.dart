// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'desktop_sidebar_layout.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DesktopSidebarLayout _$DesktopSidebarLayoutFromJson(
  Map<String, dynamic> json,
) => _DesktopSidebarLayout(
  width: (json['width'] as num?)?.toDouble() ?? 260,
  collapsed: json['collapsed'] as bool? ?? false,
  collapsedProjectIds:
      (json['collapsedProjectIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toSet() ??
      const {},
  deferredSessions:
      (json['deferredSessions'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const {},
  activitySectionCollapsed: json['activitySectionCollapsed'] as bool? ?? false,
  projectsSectionCollapsed: json['projectsSectionCollapsed'] as bool? ?? false,
);

Map<String, dynamic> _$DesktopSidebarLayoutToJson(
  _DesktopSidebarLayout instance,
) => <String, dynamic>{
  'width': instance.width,
  'collapsed': instance.collapsed,
  'collapsedProjectIds': instance.collapsedProjectIds.toList(),
  'deferredSessions': instance.deferredSessions,
  'activitySectionCollapsed': instance.activitySectionCollapsed,
  'projectsSectionCollapsed': instance.projectsSectionCollapsed,
};
