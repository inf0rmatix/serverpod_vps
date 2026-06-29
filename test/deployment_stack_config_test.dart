import 'package:serverpod_vps/serverpod_vps.dart';
import 'package:test/test.dart';

void main() {
  group('DeploymentStackConfig', () {
    test('fromProjectName derives traefik instance from network slug', () {
      final config = DeploymentStackConfig.fromProjectName('my_test_project');

      expect(config.dockerNetworkName, 'my_test_project-network');
      expect(config.traefikInstance, 'my_test_project-vps');
      expect(config.traefikHttpHostPort, 80);
      expect(config.traefikHttpsHostPort, 443);
      expect(config.postgresHostPort, 5432);
    });

    test('fromProjectName sanitizes traefik instance like network names', () {
      final config = DeploymentStackConfig.fromProjectName('my weird!name');

      expect(config.dockerNetworkName, 'my-weird-name-network');
      expect(config.traefikInstance, 'my-weird-name-vps');
    });

    test('fromProjectName accepts custom host ports', () {
      final config = DeploymentStackConfig.fromProjectName(
        'demo_project',
        traefikHttpHostPort: 8080,
        traefikHttpsHostPort: 8443,
        postgresHostPort: 55432,
      );

      expect(config.traefikHttpHostPort, 8080);
      expect(config.traefikHttpsHostPort, 8443);
      expect(config.postgresHostPort, 55432);
    });

    test('validatePort rejects invalid port numbers', () {
      expect(
        () => DeploymentStackConfig.validatePort(0, label: 'HTTP'),
        throwsArgumentError,
      );
      expect(
        () => DeploymentStackConfig.validatePort(70000, label: 'HTTPS'),
        throwsArgumentError,
      );
    });
  });
}
