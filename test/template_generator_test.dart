import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:serverpod_vps/serverpod_vps.dart';
import 'package:test/test.dart';

void main() {
  group('TemplateGenerator', () {
    late Directory tempDir;
    late TemplateGenerator generator;

    setUp(() {
      generator = TemplateGenerator();
      // Create tmp directory in repository root
      final repoRoot = Directory.current;
      final tmpDir = Directory(path.join(repoRoot.path, 'tmp'));
      if (!tmpDir.existsSync()) {
        tmpDir.createSync();
      }

      // Create a temporary directory for this test
      tempDir = Directory(path.join(tmpDir.path, 'serverpod_vps_test'))
        ..createSync();
    });

    tearDown(() {
      // Clean up the temporary directory
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('correctly identifies project directory name', () async {
      // Create a test directory with a known name
      final testDirName = 'my_test_project';
      final testDir = Directory(path.join(tempDir.path, testDirName))
        ..createSync();

      // Create server and client directories
      Directory(path.join(testDir.path, '${testDirName}_server')).createSync();
      Directory(path.join(testDir.path, '${testDirName}_client')).createSync();

      // Change to the test directory
      final originalDir = Directory.current;
      Directory.current = testDir.path;

      try {
        // Run the check
        final result = await generator.checkDirectoryStructure();

        // Verify the directory name was correctly extracted
        expect(generator.projectDirectoryName, equals(testDirName));
        expect(result, isTrue);

        expect(
          generator.projectDirectoryPath,
          equals(testDir.absolute.path),
        );
      } finally {
        // Always restore the original directory
        Directory.current = originalDir;
      }
    });

    test('throws when server directory is missing', () async {
      // Create a test directory with a known name
      final testDirName = 'my_test_project';
      final testDir = Directory(path.join(tempDir.path, testDirName))
        ..createSync();

      // Create only client directory
      Directory(path.join(testDir.path, '${testDirName}_client')).createSync();

      // Change to the test directory
      final originalDir = Directory.current;
      Directory.current = testDir.path;

      try {
        // Run the check
        expect(
          () => generator.checkDirectoryStructure(),
          throwsA(isA<Exception>()),
        );
      } finally {
        // Always restore the original directory
        Directory.current = originalDir;
      }
    });

    test(
      'generates multi-stack safe traefik and port settings in compose file',
      () async {
        const testDirName = 'stack_safe_project';
        const testEmail = 'ssl@example.com';

        final testDir = Directory(path.join(tempDir.path, testDirName))
          ..createSync();

        Directory(path.join(testDir.path, '${testDirName}_server'))
            .createSync();
        Directory(path.join(testDir.path, '${testDirName}_client'))
            .createSync();

        final originalDir = Directory.current;
        Directory.current = testDir.path;

        try {
          await generator.generateDeploymentFilesForTesting(
            email: testEmail,
            traefikHttpHostPort: 8080,
            traefikHttpsHostPort: 8443,
            postgresHostPort: 55432,
          );

          final composeContent = File(
            path.join(
              testDir.path,
              '${testDirName}_server',
              'docker-compose.production.yaml',
            ),
          ).readAsStringSync();

          expect(
            composeContent,
            contains('providers.docker.exposedbydefault=false'),
          );
          expect(
            composeContent,
            contains(
              'providers.docker.constraints=Label(`serverpod_vps.instance`,`$testDirName-vps`)',
            ),
          );
          expect(
            composeContent,
            contains('serverpod_vps.instance=$testDirName-vps'),
          );
          expect(composeContent, isNot(contains('traefik.instance=')));
          expect(
            composeContent,
            contains('traefik.http.routers.$testDirName-api.rule'),
          );
          expect(
            composeContent,
            contains('traefik.http.routers.$testDirName-web.rule'),
          );
          expect(
            composeContent,
            contains('traefik.http.routers.$testDirName-insights.rule'),
          );
          expect(
            composeContent,
            isNot(contains('traefik.http.routers.api.rule')),
          );
          expect(composeContent, contains('"8080:80"'));
          expect(composeContent, contains('"8443:443"'));
          expect(composeContent, contains('127.0.0.1:55432:5432'));
          expect(composeContent, isNot(contains('{{TRAEFIK_INSTANCE}}')));
          expect(composeContent, isNot(contains('{{TRAEFIK_HTTP_HOST_PORT}}')));
        } finally {
          Directory.current = originalDir;
        }
      },
    );

    test(
      'uses postgres image from existing docker compose file',
      () async {
        const testDirName = 'postgres_image_project';
        const testEmail = 'ssl@example.com';
        const postgresImage = 'postgis/postgis:16-3.4';

        final testDir = Directory(path.join(tempDir.path, testDirName))
          ..createSync();

        final serverDir = Directory(
          path.join(testDir.path, '${testDirName}_server'),
        )..createSync();
        Directory(path.join(testDir.path, '${testDirName}_client'))
            .createSync();

        File(path.join(serverDir.path, 'docker-compose.yaml'))
            .writeAsStringSync('''
services:
  postgres:
    image: $postgresImage
    ports:
      - "8090:5432"
''');

        final originalDir = Directory.current;
        Directory.current = testDir.path;

        try {
          await generator.generateDeploymentFilesForTesting(email: testEmail);

          final composeContent = File(
            path.join(
              testDir.path,
              '${testDirName}_server',
              'docker-compose.production.yaml',
            ),
          ).readAsStringSync();

          expect(composeContent, contains('image: $postgresImage'));
          expect(composeContent, isNot(contains('{{POSTGRES_IMAGE}}')));
          expect(composeContent, isNot(contains('image: postgres:17')));
        } finally {
          Directory.current = originalDir;
        }
      },
    );

    test(
      'does not replace projectname inside detected postgres image',
      () async {
        const testDirName = 'literal_replacement_project';
        const testEmail = 'ssl@example.com';
        const postgresImage = 'ghcr.io/acme/projectname-postgres:16';

        final testDir = Directory(path.join(tempDir.path, testDirName))
          ..createSync();

        final serverDir = Directory(
          path.join(testDir.path, '${testDirName}_server'),
        )..createSync();
        Directory(path.join(testDir.path, '${testDirName}_client'))
            .createSync();

        File(path.join(serverDir.path, 'docker-compose.yaml'))
            .writeAsStringSync('''
services:
  postgres:
    image: $postgresImage
''');

        final originalDir = Directory.current;
        Directory.current = testDir.path;

        try {
          await generator.generateDeploymentFilesForTesting(email: testEmail);

          final composeContent = File(
            path.join(
              testDir.path,
              '${testDirName}_server',
              'docker-compose.production.yaml',
            ),
          ).readAsStringSync();

          expect(composeContent, contains('image: $postgresImage'));
          expect(
            composeContent,
            isNot(contains('ghcr.io/acme/$testDirName-postgres:16')),
          );
        } finally {
          Directory.current = originalDir;
        }
      },
    );

    test(
      'defaults to current Serverpod postgres image when compose is missing',
      () async {
        const testDirName = 'default_postgres_image_project';
        const testEmail = 'ssl@example.com';

        final testDir = Directory(path.join(tempDir.path, testDirName))
          ..createSync();

        Directory(path.join(testDir.path, '${testDirName}_server'))
            .createSync();
        Directory(path.join(testDir.path, '${testDirName}_client'))
            .createSync();

        final originalDir = Directory.current;
        Directory.current = testDir.path;

        try {
          await generator.generateDeploymentFilesForTesting(email: testEmail);

          final composeContent = File(
            path.join(
              testDir.path,
              '${testDirName}_server',
              'docker-compose.production.yaml',
            ),
          ).readAsStringSync();

          expect(
            composeContent,
            contains(
              'image: ${DeploymentStackConfig.defaultPostgresImage}',
            ),
          );
        } finally {
          Directory.current = originalDir;
        }
      },
    );

    test(
      'detects postgres image from compose content',
      () {
        const composeContent = '''
services:
  postgres_test:
    image: postgres:15
  postgres:
    image: "pgvector/pgvector:pg16"
''';

        final postgresImage = generator.detectPostgresImageFromComposeContent(
          composeContent,
        );

        expect(postgresImage, equals('pgvector/pgvector:pg16'));
      },
    );

    test(
      'replaces projectname and email placeholders in generated files',
      () async {
        const testDirName = 'placeholder_test_project';
        const testEmail = 'ssl@example.com';

        final testDir = Directory(path.join(tempDir.path, testDirName))
          ..createSync();

        Directory(path.join(testDir.path, '${testDirName}_server'))
            .createSync();
        Directory(path.join(testDir.path, '${testDirName}_client'))
            .createSync();

        final originalDir = Directory.current;
        Directory.current = testDir.path;

        try {
          await generator.generateDeploymentFilesForTesting(email: testEmail);

          final composeContent = File(
            path.join(
              testDir.path,
              '${testDirName}_server',
              'docker-compose.production.yaml',
            ),
          ).readAsStringSync();

          final workflowContent = File(
            path.join(
              testDir.path,
              '.github',
              'workflows',
              'deployment-docker.yml',
            ),
          ).readAsStringSync();

          expect(composeContent, isNot(contains('projectname')));
          expect(composeContent, isNot(contains('{{DOCKER_NETWORK_NAME}}')));
          expect(workflowContent, isNot(contains('projectname')));
          expect(composeContent, isNot(contains('serverpod-network')));
          expect(composeContent, contains('$testDirName-network'));
          expect(workflowContent, contains('${testDirName}_server'));
          expect(composeContent, contains(testEmail));
        } finally {
          Directory.current = originalDir;
        }
      },
    );

    test(
      'sanitizes docker network names for projects with invalid characters',
      () async {
        const testDirName = 'my weird!name';
        const expectedNetworkName = 'my-weird-name-network';

        final testDir = Directory(path.join(tempDir.path, 'weird_name_project'))
          ..createSync();

        Directory(path.join(testDir.path, '${testDirName}_server'))
            .createSync();
        Directory(path.join(testDir.path, '${testDirName}_client'))
            .createSync();

        final originalDir = Directory.current;
        Directory.current = testDir.path;

        try {
          await generator.generateDeploymentFilesForTesting(
            email: 'ssl@example.com',
          );

          final composeContent = File(
            path.join(
              testDir.path,
              '${testDirName}_server',
              'docker-compose.production.yaml',
            ),
          ).readAsStringSync();

          expect(composeContent, contains(expectedNetworkName));
          expect(composeContent, isNot(contains('{{DOCKER_NETWORK_NAME}}')));
          expect(composeContent, isNot(contains('$testDirName-network')));
          expect(DockerNetworkName.isValid(expectedNetworkName), isTrue);
        } finally {
          Directory.current = originalDir;
        }
      },
    );

    test(
      'includes IdP JWT password env vars in generated deployment files',
      () async {
        const testDirName = 'password_env_test_project';
        const testEmail = 'test@example.com';

        final testDir = Directory(path.join(tempDir.path, testDirName))
          ..createSync();

        Directory(path.join(testDir.path, '${testDirName}_server'))
            .createSync();
        Directory(path.join(testDir.path, '${testDirName}_client'))
            .createSync();

        final originalDir = Directory.current;
        Directory.current = testDir.path;

        try {
          await generator.generateDeploymentFilesForTesting(email: testEmail);

          final composeContent = File(
            path.join(
              testDir.path,
              '${testDirName}_server',
              'docker-compose.production.yaml',
            ),
          ).readAsStringSync();

          final workflowContent = File(
            path.join(
              testDir.path,
              '.github',
              'workflows',
              'deployment-docker.yml',
            ),
          ).readAsStringSync();

          const passwordEnvVars = [
            'SERVERPOD_PASSWORD_emailSecretHashPepper',
            'SERVERPOD_PASSWORD_jwtHmacSha512PrivateKey',
            'SERVERPOD_PASSWORD_jwtRefreshTokenHashPepper',
          ];

          const githubSecrets = [
            'SERVERPOD_PASSWORD_EMAIL_SECRET_HASH_PEPPER',
            'SERVERPOD_PASSWORD_JWT_HMAC_SHA512_PRIVATE_KEY',
            'SERVERPOD_PASSWORD_JWT_REFRESH_TOKEN_HASH_PEPPER',
          ];

          for (final envVar in passwordEnvVars) {
            expect(composeContent, contains(envVar));
            expect(workflowContent, contains(envVar));
          }

          for (final secret in githubSecrets) {
            expect(workflowContent, contains(secret));
          }
        } finally {
          Directory.current = originalDir;
        }
      },
    );

    test('throws when client directory is missing', () async {
      // Create a test directory with a known name
      final testDirName = 'my_test_project';
      final testDir = Directory(path.join(tempDir.path, testDirName))
        ..createSync();

      // Create only server directory
      Directory(path.join(testDir.path, '${testDirName}_server')).createSync();

      // Change to the test directory
      final originalDir = Directory.current;
      Directory.current = testDir.path;

      try {
        // Run the check
        expect(
          () => generator.checkDirectoryStructure(),
          throwsA(isA<Exception>()),
        );
      } finally {
        // Always restore the original directory
        Directory.current = originalDir;
      }
    });

    group('findProjectName', () {
      test('correctly extracts project name from matching directories', () {
        // Create a test directory with a known name
        final testDirName = 'my_test_project';
        final testDir = Directory(path.join(tempDir.path, testDirName))
          ..createSync();

        // Create server and client directories
        Directory(path.join(testDir.path, '${testDirName}_server'))
            .createSync();
        Directory(path.join(testDir.path, '${testDirName}_client'))
            .createSync();

        // Change to the test directory
        final originalDir = Directory.current;
        Directory.current = testDir.path;

        try {
          final projectName = generator.findProjectName();
          expect(projectName, equals(testDirName));
        } finally {
          // Always restore the original directory
          Directory.current = originalDir;
        }
      });

      test('throws when directories have mismatched names', () {
        // Create a test directory
        final testDir = Directory(path.join(tempDir.path, 'test_dir'))
          ..createSync();

        // Create mismatched server and client directories
        Directory(path.join(testDir.path, 'project1_server')).createSync();
        Directory(path.join(testDir.path, 'project2_client')).createSync();

        // Change to the test directory
        final originalDir = Directory.current;
        Directory.current = testDir.path;

        try {
          expect(
            () => generator.findProjectName(),
            throwsA(isA<Exception>()),
          );
        } finally {
          // Always restore the original directory
          Directory.current = originalDir;
        }
      });

      test('throws when only server directory exists', () {
        // Create a test directory
        final testDir = Directory(path.join(tempDir.path, 'test_dir'))
          ..createSync();

        // Create only server directory
        Directory(path.join(testDir.path, 'project_server')).createSync();

        // Change to the test directory
        final originalDir = Directory.current;
        Directory.current = testDir.path;

        try {
          expect(
            () => generator.findProjectName(),
            throwsA(isA<Exception>()),
          );
        } finally {
          // Always restore the original directory
          Directory.current = originalDir;
        }
      });

      test('throws when only client directory exists', () {
        // Create a test directory
        final testDir = Directory(path.join(tempDir.path, 'test_dir'))
          ..createSync();

        // Create only client directory
        Directory(path.join(testDir.path, 'project_client')).createSync();

        // Change to the test directory
        final originalDir = Directory.current;
        Directory.current = testDir.path;

        try {
          expect(
            () => generator.findProjectName(),
            throwsA(isA<Exception>()),
          );
        } finally {
          // Always restore the original directory
          Directory.current = originalDir;
        }
      });
    });
  });

  group('deployment workflow template', () {
    late String workflowTemplate;

    setUp(() {
      workflowTemplate = File(
        path.join(
          Directory.current.path,
          'lib',
          'assets',
          'templates',
          'serverpod_templates',
          'github',
          'workflows',
          'deployment-docker.yml',
        ),
      ).readAsStringSync();
    });

    test('builds Docker image for linux/arm64', () {
      expect(workflowTemplate, contains('platforms: linux/arm64'));
    });

    test('builds Docker image from project root context', () {
      expect(workflowTemplate, contains('context: .'));
      expect(
        workflowTemplate,
        contains('file: ./projectname_server/Dockerfile.prod'),
      );
      expect(
        workflowTemplate,
        isNot(contains('context: ./projectname_server')),
      );
    });
  });

  group('production Dockerfile template', () {
    late String dockerfileTemplate;

    setUp(() {
      dockerfileTemplate = File(
        path.join(
          Directory.current.path,
          'lib',
          'assets',
          'templates',
          'serverpod_templates',
          'projectname_server',
          'Dockerfile.prod',
        ),
      ).readAsStringSync();
    });

    test('builds and copies Flutter web app into server web app directory', () {
      expect(
        dockerfileTemplate,
        contains('flutter build web --release --base-href /app/'),
      );
      expect(dockerfileTemplate, contains('/app/flutter_web'));
      expect(dockerfileTemplate, contains('web/app'));
    });

    test('uses current Serverpod server build bundle layout', () {
      expect(dockerfileTemplate, contains('dart build cli'));
      expect(
        dockerfileTemplate,
        contains('WORKDIR /app/projectname_server\nRUN dart pub get'),
      );
      expect(
        dockerfileTemplate,
        contains(
          'lib/src/generated/protocol.yaml lib/src/generated/protocol.yaml',
        ),
      );
      expect(dockerfileTemplate, contains('ENTRYPOINT ./bin/server'));
    });
  });
}
