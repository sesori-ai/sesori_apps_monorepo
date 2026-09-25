/// Native I/O for the single master item in the selected persistence scope.
///
/// The shell adapter owns namespace selection and native options, not key
/// generation, caching or recovery policy. Null means an absent native item;
/// denied access and other failures must remain failed futures, never resets.
abstract interface class MasterKeyStore() {
  Future<String?> read();

  Future<void> write({required String value});
}
