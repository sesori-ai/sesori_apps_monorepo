import "package:injectable/injectable.dart";

import "../foundation/platform/founder_call_config_source.dart";

@lazySingleton
class FounderCallConfigApi({required final FounderCallConfigSource _source}) {
  Future<FounderCallConfigValues> fetchValues() => _source.fetchValues();
}
