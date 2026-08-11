/// Builds a successful raw Pi RPC response for transport and mapper tests.
Map<String, Object?> piSuccessResponseFixture({
  required String id,
  required String command,
  Map<String, Object?> data = const {},
}) => {"id": id, "type": "response", "command": command, "success": true, "data": data};

/// Builds a failed raw Pi RPC response for transport and mapper tests.
Map<String, Object?> piFailureResponseFixture({
  required String id,
  required String command,
  required String error,
}) => {"id": id, "type": "response", "command": command, "success": false, "error": error};

/// Builds a raw Pi event while keeping each test's payload explicit.
Map<String, Object?> piEventFixture({required String type, Map<String, Object?> fields = const {}}) => {
  "type": type,
  ...fields,
};
