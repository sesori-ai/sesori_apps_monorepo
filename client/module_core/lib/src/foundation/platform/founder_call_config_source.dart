/// Raw remote values for the CEO call invitation. Each is null when the source
/// has none; the repository validates them and applies the defaults.
typedef FounderCallConfigValues = ({
  bool? enabled,
  bool? afterComputer,
  String? bookingUrl,
  String? title,
  String? message,
  String? buttonLabel,
});

abstract interface class FounderCallConfigSource() {
  Future<FounderCallConfigValues> fetchValues();
}
