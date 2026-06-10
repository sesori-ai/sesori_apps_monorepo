import 'package:sesori_bridge/src/bridge/runtime/bridge_cli_dispatch.dart';
import 'package:test/test.dart';

void main() {
  group('effectiveCliArgs', () {
    test('no arguments defaults to the run command', () {
      expect(effectiveCliArgs(<String>[]), equals(<String>['run']));
    });

    test('leading --help is passed through for the global command overview', () {
      expect(effectiveCliArgs(<String>['--help']), equals(<String>['--help']));
      expect(effectiveCliArgs(<String>['-h']), equals(<String>['-h']));
    });

    test('leading flag is routed to the implicit run command', () {
      expect(
        effectiveCliArgs(<String>['--relay', 'wss://example.com']),
        equals(<String>['run', '--relay', 'wss://example.com']),
      );
      expect(effectiveCliArgs(<String>['--version']), equals(<String>['run', '--version']));
    });

    test('--help after run flags is routed to the run command', () {
      expect(
        effectiveCliArgs(<String>['--port', '4000', '--help']),
        equals(<String>['run', '--port', '4000', '--help']),
      );
    });

    test('explicit commands are passed through unchanged', () {
      expect(effectiveCliArgs(<String>['logout']), equals(<String>['logout']));
      expect(effectiveCliArgs(<String>['config']), equals(<String>['config']));
      expect(effectiveCliArgs(<String>['help']), equals(<String>['help']));
      expect(
        effectiveCliArgs(<String>['run', '--port', '4000']),
        equals(<String>['run', '--port', '4000']),
      );
    });

    test('unknown commands are passed through for CommandRunner to report', () {
      expect(effectiveCliArgs(<String>['bogus']), equals(<String>['bogus']));
    });
  });
}
