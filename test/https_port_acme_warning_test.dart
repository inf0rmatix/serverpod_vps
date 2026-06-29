import 'package:serverpod_vps/serverpod_vps.dart';
import 'package:test/test.dart';

void main() {
  group('HttpsPortAcmeWarning', () {
    test('shouldWarn is false for the default HTTPS port', () {
      expect(
        HttpsPortAcmeWarning.shouldWarn(
          DeploymentStackConfig.defaultTraefikHttpsHostPort,
        ),
        isFalse,
      );
    });

    test('shouldWarn is true for non-standard HTTPS ports', () {
      expect(HttpsPortAcmeWarning.shouldWarn(8443), isTrue);
    });

    test('warningLines mention DNS challenge and Cloudflare setup', () {
      final message = HttpsPortAcmeWarning.warningLines(8443).join('\n');

      expect(message, contains('8443'));
      expect(message, contains('dnschallenge=true'));
      expect(message, contains('cloudflare'));
      expect(message, contains('CF_DNS_API_TOKEN'));
      expect(message, contains('publicPort: 8443'));
      expect(message, contains('SERVERPOD_*_PUBLIC_PORT'));
    });
  });
}
