import "package:injectable/injectable.dart";

import "../api/founder_call_config_api.dart";
import "../api/storage/founder_call_storage.dart";
import "../foundation/models/founder_call/founder_call_config.dart";
import "../foundation/models/founder_call/founder_call_progress.dart";
import "../foundation/platform/founder_call_config_source.dart";
import "../logging/logging.dart";

@lazySingleton
class FounderCallRepository({
  required final FounderCallConfigApi _configApi,
  required final FounderCallStorage _storage,
}) {
  static final Uri defaultBookingUrl = Uri.parse(defaultFounderCallBookingUrl);

  /// The remote rule, with the built-in default for every missing value: the
  /// invitation and its computer-connected sheet are on, and it books at
  /// [defaultBookingUrl] with the built-in wording.
  Future<FounderCallConfig> readConfig() async {
    final values = await _configApi.fetchValues();
    if (values.enabled == false) return const FounderCallDisabled();
    return FounderCallEnabled(
      bookingUrl: _bookingUrl(value: values.bookingUrl),
      afterComputer: values.afterComputer ?? true,
      copy: FounderCallCopy(
        title: _text(value: values.title),
        message: _text(value: values.message),
        buttonLabel: _text(value: values.buttonLabel),
      ),
    );
  }

  /// This device's progress; a device that never stored any was never armed.
  Future<FounderCallProgress> readProgress() async => await _storage.read() ?? const FounderCallUnarmed();

  Future<void> writeProgress({required FounderCallStoredProgress progress}) => _storage.write(progress: progress);
}

/// Only an https link with a host is opened; anything else falls back to the
/// default so a console typo cannot send users somewhere unexpected.
Uri _bookingUrl({required String? value}) {
  if (value == null) return FounderCallRepository.defaultBookingUrl;
  final url = Uri.tryParse(value.trim());
  if (url != null && url.isScheme("https") && url.host.isNotEmpty) return url;
  logw("Ignoring an invalid remote founder call booking link; using the default");
  return FounderCallRepository.defaultBookingUrl;
}

String? _text({required String? value}) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
