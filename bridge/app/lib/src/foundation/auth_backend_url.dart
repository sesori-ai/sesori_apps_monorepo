String normalizeAuthBackendUrl({required String url}) => url.replaceFirst(RegExp(r"/+$"), "");
