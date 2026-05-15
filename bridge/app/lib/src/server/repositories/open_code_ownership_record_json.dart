import 'open_code_ownership_record.dart';

class OpenCodeOwnershipFileJson {
  final Map<String, OpenCodeOwnershipRecordJson> recordsByOwnerSessionId;

  const OpenCodeOwnershipFileJson({required this.recordsByOwnerSessionId});

  factory OpenCodeOwnershipFileJson.fromJson(Map<String, dynamic> json) {
    final records = <String, OpenCodeOwnershipRecordJson>{};
    for (final MapEntry<String, dynamic> entry in json.entries) {
      records[entry.key] = OpenCodeOwnershipRecordJson.fromJson(
        ownerSessionId: entry.key,
        json: Map<String, dynamic>.from(entry.value as Map),
      );
    }

    return OpenCodeOwnershipFileJson(recordsByOwnerSessionId: records);
  }

  factory OpenCodeOwnershipFileJson.fromRecords(
    Map<String, OpenCodeOwnershipRecord> records,
  ) {
    return OpenCodeOwnershipFileJson(
      recordsByOwnerSessionId: <String, OpenCodeOwnershipRecordJson>{
        for (final MapEntry<String, OpenCodeOwnershipRecord> entry in records.entries)
          entry.key: OpenCodeOwnershipRecordJson.fromRecord(entry.value),
      },
    );
  }

  Map<String, OpenCodeOwnershipRecord> toRecords() {
    return <String, OpenCodeOwnershipRecord>{
      for (final MapEntry<String, OpenCodeOwnershipRecordJson> entry
          in recordsByOwnerSessionId.entries)
        entry.key: entry.value.toRecord(),
    };
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      for (final MapEntry<String, OpenCodeOwnershipRecordJson> entry
          in recordsByOwnerSessionId.entries)
        entry.key: entry.value.toJson(),
    };
  }
}

class OpenCodeOwnershipRecordJson {
  final String ownerSessionId;
  final int openCodePid;
  final String? openCodeStartMarker;
  final String openCodeExecutablePath;
  final String openCodeCommand;
  final List<String> openCodeArgs;
  final int port;
  final int bridgePid;
  final String? bridgeStartMarker;
  final String startedAt;
  final String status;

  const OpenCodeOwnershipRecordJson({
    required this.ownerSessionId,
    required this.openCodePid,
    required this.openCodeStartMarker,
    required this.openCodeExecutablePath,
    required this.openCodeCommand,
    required this.openCodeArgs,
    required this.port,
    required this.bridgePid,
    required this.bridgeStartMarker,
    required this.startedAt,
    required this.status,
  });

  factory OpenCodeOwnershipRecordJson.fromJson({
    required String ownerSessionId,
    required Map<String, dynamic> json,
  }) {
    final String jsonOwnerSessionId = json['ownerSessionId'] as String;
    if (jsonOwnerSessionId != ownerSessionId) {
      throw FormatException(
        'ownership record key $ownerSessionId does not match payload ownerSessionId $jsonOwnerSessionId',
      );
    }

    return OpenCodeOwnershipRecordJson(
      ownerSessionId: jsonOwnerSessionId,
      openCodePid: json['openCodePid'] as int,
      openCodeStartMarker: json['openCodeStartMarker'] as String?,
      openCodeExecutablePath: json['openCodeExecutablePath'] as String,
      openCodeCommand: json['openCodeCommand'] as String,
      openCodeArgs: (json['openCodeArgs'] as List<dynamic>).cast<String>(),
      port: json['port'] as int,
      bridgePid: json['bridgePid'] as int,
      bridgeStartMarker: json['bridgeStartMarker'] as String?,
      startedAt: json['startedAt'] as String,
      status: json['status'] as String,
    );
  }

  factory OpenCodeOwnershipRecordJson.fromRecord(OpenCodeOwnershipRecord record) {
    return OpenCodeOwnershipRecordJson(
      ownerSessionId: record.ownerSessionId,
      openCodePid: record.openCodePid,
      openCodeStartMarker: record.openCodeStartMarker,
      openCodeExecutablePath: record.openCodeExecutablePath,
      openCodeCommand: record.openCodeCommand,
      openCodeArgs: record.openCodeArgs,
      port: record.port,
      bridgePid: record.bridgePid,
      bridgeStartMarker: record.bridgeStartMarker,
      startedAt: record.startedAt.toUtc().toIso8601String(),
      status: record.status.name,
    );
  }

  OpenCodeOwnershipRecord toRecord() {
    return OpenCodeOwnershipRecord(
      ownerSessionId: ownerSessionId,
      openCodePid: openCodePid,
      openCodeStartMarker: openCodeStartMarker,
      openCodeExecutablePath: openCodeExecutablePath,
      openCodeCommand: openCodeCommand,
      openCodeArgs: openCodeArgs,
      port: port,
      bridgePid: bridgePid,
      bridgeStartMarker: bridgeStartMarker,
      startedAt: DateTime.parse(startedAt),
      status: OpenCodeOwnershipStatus.values.byName(status),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ownerSessionId': ownerSessionId,
      'openCodePid': openCodePid,
      'openCodeStartMarker': openCodeStartMarker,
      'openCodeExecutablePath': openCodeExecutablePath,
      'openCodeCommand': openCodeCommand,
      'openCodeArgs': openCodeArgs,
      'port': port,
      'bridgePid': bridgePid,
      'bridgeStartMarker': bridgeStartMarker,
      'startedAt': startedAt,
      'status': status,
    };
  }
}
