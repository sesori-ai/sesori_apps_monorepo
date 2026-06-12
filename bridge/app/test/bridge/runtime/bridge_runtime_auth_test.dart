import 'package:sesori_bridge/src/auth/login_email_api.dart';
import 'package:sesori_bridge/src/auth/login_email_repository.dart';
import 'package:sesori_bridge/src/auth/login_oauth_service.dart';
import 'package:sesori_bridge/src/auth/token.dart';
import 'package:sesori_bridge/src/bridge/foundation/post_update_restart_flag.dart';
import 'package:sesori_bridge/src/bridge/runtime/bridge_runtime_auth.dart';
import 'package:sesori_shared/sesori_shared.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeRuntimeAuthService', () {
    test('promptForProvider throws post-update non-interactive login guidance without reading stdin', () async {
      final service = BridgeRuntimeAuthService(
        loginEmailRepository: _FakeLoginEmailRepository(),
        loginOAuthService: _FakeLoginOAuthService(),
        environment: const <String, String>{sesoriPostUpdateRestartEnvVar: '1'},
      );

      await expectLater(
        service.promptForProvider(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Login required, but this bridge was relaunched non-interactively after an auto-update'),
          ),
        ),
      );
    });
  });
}

class _FakeLoginEmailRepository implements LoginEmailRepository {
  @override
  LoginEmailApi get emailAuthApi => throw UnimplementedError();

  @override
  ({String email, String password}) Function() get promptForCredentials => throw UnimplementedError();

  @override
  Future<TokenData> performEmailLogin() {
    throw UnimplementedError();
  }
}

class _FakeLoginOAuthService implements LoginOAuthService {
  @override
  Future<TokenData> performOAuthLogin(OAuthProvider provider) {
    throw UnimplementedError();
  }
}
