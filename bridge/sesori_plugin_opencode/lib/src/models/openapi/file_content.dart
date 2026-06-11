// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class FileContent {
  const FileContent({
    required this.type,
    required this.content,
    this.diff,
    this.patch,
    this.encoding,
    this.mimeType,
  });

  factory FileContent.fromJson(Map<String, dynamic> json) {
    return FileContent(
      type: json["type"] as String,
      content: json["content"] as String,
      diff: json["diff"] as String?,
      patch: json["patch"] == null ? null : FileContentPatch.fromJson(json["patch"] as Map<String, dynamic>),
      encoding: json["encoding"] as String?,
      mimeType: json["mimeType"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "content": content,
      "diff": ?diff,
      "patch": ?patch?.toJson(),
      "encoding": ?encoding,
      "mimeType": ?mimeType,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileContent &&
          other.type == type &&
          other.content == content &&
          other.diff == diff &&
          other.patch == patch &&
          other.encoding == encoding &&
          other.mimeType == mimeType);

  @override
  int get hashCode => Object.hash(type, content, diff, patch, encoding, mimeType);

  final String type;
  final String content;
  final String? diff;
  final FileContentPatch? patch;
  final String? encoding;
  final String? mimeType;
}

@immutable
class FileContentPatch {
  const FileContentPatch({
    required this.oldFileName,
    required this.newFileName,
    this.oldHeader,
    this.newHeader,
    required this.hunks,
    this.index,
  });

  factory FileContentPatch.fromJson(Map<String, dynamic> json) {
    return FileContentPatch(
      oldFileName: json["oldFileName"] as String,
      newFileName: json["newFileName"] as String,
      oldHeader: json["oldHeader"] as String?,
      newHeader: json["newHeader"] as String?,
      hunks: (json["hunks"] as List<dynamic>).map((e) => FileContentPatchHunksItem.fromJson(e as Map<String, dynamic>)).toList(),
      index: json["index"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "oldFileName": oldFileName,
      "newFileName": newFileName,
      "oldHeader": ?oldHeader,
      "newHeader": ?newHeader,
      "hunks": hunks.map((e) => e.toJson()).toList(),
      "index": ?index,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileContentPatch &&
          other.oldFileName == oldFileName &&
          other.newFileName == newFileName &&
          other.oldHeader == oldHeader &&
          other.newHeader == newHeader &&
          const DeepCollectionEquality().equals(other.hunks, hunks) &&
          other.index == index);

  @override
  int get hashCode => Object.hash(oldFileName, newFileName, oldHeader, newHeader, const DeepCollectionEquality().hash(hunks), index);

  final String oldFileName;
  final String newFileName;
  final String? oldHeader;
  final String? newHeader;
  final List<FileContentPatchHunksItem> hunks;
  final String? index;
}

@immutable
class FileContentPatchHunksItem {
  const FileContentPatchHunksItem({
    required this.oldStart,
    required this.oldLines,
    required this.newStart,
    required this.newLines,
    required this.lines,
  });

  factory FileContentPatchHunksItem.fromJson(Map<String, dynamic> json) {
    return FileContentPatchHunksItem(
      oldStart: (json["oldStart"] as num).toInt(),
      oldLines: (json["oldLines"] as num).toInt(),
      newStart: (json["newStart"] as num).toInt(),
      newLines: (json["newLines"] as num).toInt(),
      lines: (json["lines"] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "oldStart": oldStart,
      "oldLines": oldLines,
      "newStart": newStart,
      "newLines": newLines,
      "lines": lines,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileContentPatchHunksItem &&
          other.oldStart == oldStart &&
          other.oldLines == oldLines &&
          other.newStart == newStart &&
          other.newLines == newLines &&
          const DeepCollectionEquality().equals(other.lines, lines));

  @override
  int get hashCode => Object.hash(oldStart, oldLines, newStart, newLines, const DeepCollectionEquality().hash(lines));

  final int oldStart;
  final int oldLines;
  final int newStart;
  final int newLines;
  final List<String> lines;
}
