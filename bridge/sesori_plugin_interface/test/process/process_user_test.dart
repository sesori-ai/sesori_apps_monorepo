import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('ProcessUser.fromRawUser', () {
    test('returns null for null input', () {
      expect(ProcessUser.fromRawUser(null), isNull);
    });

    test('returns null for empty or whitespace-only input', () {
      expect(ProcessUser.fromRawUser(''), isNull);
      expect(ProcessUser.fromRawUser('   '), isNull);
    });

    test('equates users differing only in case', () {
      expect(ProcessUser.fromRawUser('Alice'), equals(ProcessUser.fromRawUser('alice')));
    });

    test('equates a Windows domain-qualified user with its bare name', () {
      expect(ProcessUser.fromRawUser(r'DOMAIN\Alice'), equals(ProcessUser.fromRawUser('alice')));
    });

    test('does not equate different users', () {
      expect(ProcessUser.fromRawUser('alice'), isNot(equals(ProcessUser.fromRawUser('bob'))));
    });

    test('trims surrounding whitespace before comparing', () {
      expect(ProcessUser.fromRawUser('  alice  '), equals(ProcessUser.fromRawUser('alice')));
    });
  });
}
