import 'dart:io';

import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

class TemplateGenerator {
  late final ArgParser _argParser;
  final logger = Logger();

  // Store directory info
  late final String projectDirectoryName;
  late final String projectDirectoryPath;

  TemplateGenerator() {
    _argParser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Show this help message',
        negatable: false,
      );
  }

  Future<void> run(List<String> arguments) async {
    try {
      final results = _argParser.parse(arguments);

      if (results['help'] as bool) {
        _printUsage();

        return;
      }

      // Use current directory by default
      if (!await checkDirectoryStructure()) {
        exit(1);
      }

      logger.info('Project directory: $projectDirectoryPath');
      logger.info('Project directory name: $projectDirectoryName');

      await _generateTemplate();
    } catch (e) {
      logger.err('Error: $e');
      _printUsage();
      exit(1);
    }
  }

  @visibleForTesting
  Future<bool> checkDirectoryStructure() async {
    // Get normalized absolute path to avoid any '.' references
    projectDirectoryPath = Directory.current.absolute.path;

    // Get the directory name from the path
    projectDirectoryName = path.basename(
      path.normalize(projectDirectoryPath),
    );

    logger.info(
      'Checking directory structure in: $projectDirectoryPath',
    );

    // Check for required subdirectories
    final serverDir = Directory(
      path.join(
        projectDirectoryPath,
        '${projectDirectoryName}_server',
      ),
    );
    final clientDir = Directory(
      path.join(
        projectDirectoryPath,
        '${projectDirectoryName}_client',
      ),
    );

    if (!await serverDir.exists()) {
      logger.err('Missing server directory: ${projectDirectoryName}_server');
      logger.info('Expected directory structure:');
      logger.info('  $projectDirectoryName/');
      logger.info('  ├── ${projectDirectoryName}_server/');
      logger.info('  └── ${projectDirectoryName}_client/');
      return false;
    }

    if (!await clientDir.exists()) {
      logger.err('Missing client directory: ${projectDirectoryName}_client');
      logger.info('Expected directory structure:');
      logger.info('  $projectDirectoryName/');
      logger.info('  ├── ${projectDirectoryName}_server/');
      logger.info('  └── ${projectDirectoryName}_client/');
      return false;
    }

    logger.success('Directory structure is valid');
    return true;
  }

  Future<void> _generateTemplate() async {
    logger.success('Generating template for project: $projectDirectoryName');
    logger.detail('Project directory: $projectDirectoryPath');

    final progress = logger.progress('Generating template');

    try {
      // TODO: Implement template generation logic
      await Future.delayed(Duration(seconds: 1)); // Simulating work

      progress.complete('Template generated successfully');
    } catch (e) {
      progress.fail('Failed to generate template');
      logger.err('Error: $e');
      exit(1);
    }
  }

  void _printUsage() {
    logger.info('Usage: serverpod_vps');
    logger.info('Run this command in your Serverpod project directory.');
    logger.info(_argParser.usage);
  }
}
