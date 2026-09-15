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
);

Map<String, dynamic> _$DesktopSidebarLayoutToJson(
  _DesktopSidebarLayout instance,
) => <String, dynamic>{
  'width': instance.width,
  'collapsed': instance.collapsed,
};
