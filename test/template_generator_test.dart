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
}
