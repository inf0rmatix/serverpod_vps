import 'docker_network_name.dart';

/// Host port and Traefik isolation settings for a generated VPS stack.
class DeploymentStackConfig {
  const DeploymentStackConfig({
    required this.dockerNetworkName,
    required this.traefikInstance,
    required this.traefikHttpHostPort,
    required this.traefikHttpsHostPort,
    required this.postgresHostPort,
  });

  final String dockerNetworkName;
  final String traefikInstance;
  final int traefikHttpHostPort;
  final int traefikHttpsHostPort;
  final int postgresHostPort;

  /// Builds stack settings from a project directory name.
  static DeploymentStackConfig fromProjectName(
    String projectName, {
    int traefikHttpHostPort = defaultTraefikHttpHostPort,
    int traefikHttpsHostPort = defaultTraefikHttpsHostPort,
    int postgresHostPort = defaultPostgresHostPort,
  }) {
    final networkResult = DockerNetworkName.buildFromProjectName(projectName);
    final stackSlug = networkResult.networkName.replaceFirst(
      RegExp(r'-network$'),
      '',
    );

    return DeploymentStackConfig(
      dockerNetworkName: networkResult.networkName,
      traefikInstance: '$stackSlug-vps',
      traefikHttpHostPort: validatePort(
        traefikHttpHostPort,
        label: 'Traefik HTTP host port',
      ),
      traefikHttpsHostPort: validatePort(
        traefikHttpsHostPort,
        label: 'Traefik HTTPS host port',
      ),
      postgresHostPort: validatePort(
        postgresHostPort,
        label: 'Postgres host port',
      ),
    );
  }

  static const int defaultTraefikHttpHostPort = 80;
  static const int defaultTraefikHttpsHostPort = 443;
  static const int defaultPostgresHostPort = 5432;

  /// Validates a TCP/UDP port number for Docker host bindings.
  static int validatePort(int port, {required String label}) {
    if (port < 1 || port > 65535) {
      throw ArgumentError.value(
        port,
        'port',
        '$label must be between 1 and 65535.',
      );
    }

    return port;
  }
}
