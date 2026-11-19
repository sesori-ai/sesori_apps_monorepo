import "dart:convert";

import "package:drift/drift.dart";
import "package:sesori_shared/sesori_shared.dart";

class const PendingPageConverter() extends TypeConverter<PendingPage, String> {
  @override
  PendingPage fromSql(String fromDb) => PendingPage.fromJson(jsonDecodeMap(fromDb));

  @override
  String toSql(PendingPage value) => jsonEncode(value.toJson());
}
