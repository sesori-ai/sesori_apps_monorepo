/// Field readers shared by the hand-written Pi transport variants.
///
/// Pi's stdout is a foreign process: a frame may omit a field or carry an
/// unexpected type, and dropping the whole frame over one bad field would lose
/// a turn. Every reader therefore degrades instead of throwing.
library;

String? stringOrNull(Object? value) => value is String ? value : null;

bool boolOrFalse(Object? value) => value is bool && value;

int? intOrNull(Object? value) => value is num ? value.toInt() : null;

Map<String, Object?> mapOrEmpty(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const <String, Object?>{};

List<String>? stringListOrNull(Object? value) => value is List
    ? [
        for (final entry in value)
          if (entry is String) entry,
      ]
    : null;
