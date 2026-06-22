import 'package:serverpod_vps/serverpod_vps.dart';
import 'package:test/test.dart';

void main() {
  group('DockerNetworkName', () {
    test(
        'fromProjectName keeps valid project names and appends -network suffix',
        () {
      expect(
        DockerNetworkName.fromProjectName('my_test_project'),
        'my_test_project-network',
      );
      expect(
        DockerNetworkName.fromProjectName('demo.project'),
        'demo.project-network',
      );
    });

    test('fromProjectName replaces invalid characters with hyphens', () {
      expect(
        DockerNetworkName.fromProjectName('my weird!name'),
        'my-weird-name-network',
      );
      expect(
        DockerNetworkName.fromProjectName('foo@bar#baz'),
        'foo-bar-baz-network',
      );
    });

    test(
      'fromProjectName prefixes names that do not start with a letter or digit',
      () {
        expect(
          DockerNetworkName.fromProjectName('---'),
          'serverpod-network',
        );
        expect(
          DockerNetworkName.fromProjectName('.hidden'),
          'hidden-network',
        );
      },
    );

    test('fromProjectName truncates names longer than Docker allows', () {
      final longProjectName = 'a' * 80;
      final networkName = DockerNetworkName.fromProjectName(longProjectName);

      expect(networkName.length, lessThanOrEqualTo(63));
      expect(DockerNetworkName.isValid(networkName), isTrue);
      expect(networkName, endsWith('-network'));
    });

    test('fromProjectName always returns a valid Docker network name', () {
      final projectNames = [
        'my_test_project',
        'My App',
        '@weird',
        '---',
        'a' * 80,
        'foo..bar',
      ];

      for (final projectName in projectNames) {
        final networkName = DockerNetworkName.fromProjectName(projectName);

        expect(
          DockerNetworkName.isValid(networkName),
          isTrue,
          reason: 'Invalid network name for project "$projectName": '
              '$networkName',
        );
      }
    });

    test('buildFromProjectName reports sanitization and truncation', () {
      expect(
        DockerNetworkName.buildFromProjectName('my_test_project'),
        (
          networkName: 'my_test_project-network',
          wasSanitized: false,
          wasTruncated: false,
        ),
      );

      expect(
        DockerNetworkName.buildFromProjectName('my weird!name'),
        (
          networkName: 'my-weird-name-network',
          wasSanitized: true,
          wasTruncated: false,
        ),
      );

      final longProjectName = 'a' * 80;
      final truncatedResult = DockerNetworkName.buildFromProjectName(
        longProjectName,
      );

      expect(truncatedResult.wasSanitized, isFalse);
      expect(truncatedResult.wasTruncated, isTrue);
      expect(truncatedResult.networkName.length, lessThanOrEqualTo(63));

      final sanitizedAndTruncatedResult =
          DockerNetworkName.buildFromProjectName(
        '${'a' * 70} weird!name',
      );

      expect(sanitizedAndTruncatedResult.wasSanitized, isTrue);
      expect(sanitizedAndTruncatedResult.wasTruncated, isTrue);
    });
  });
}
