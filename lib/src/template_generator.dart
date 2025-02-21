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

      logger.info('');
      logger.info(
        backgroundBlue.wrap(
          white.wrap(
            '\t========================================================\t',
          ),
        ),
      );
      logger.info(
        backgroundBlue.wrap(
          white.wrap('\t\t  🚀 Serverpod VPS Deployment Generator\t\t\t'),
        ),
      );
      logger.info(
        backgroundBlue.wrap(
          white.wrap(
            '\t========================================================\t',
          ),
        ),
      );
      logger.info('');

      // Use current directory by default
      if (!await checkDirectoryStructure()) {
        exit(1);
      }

      logger.info(
        'Project directory: ${styleBold.wrap(projectDirectoryPath)}',
      );

      logger.info(
        'Project directory name: ${styleBold.wrap(projectDirectoryName)}',
      );

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
      // Check for environment variable
      var templatesDir = Platform.environment['SERVERPOD_VPS_ASSETS'];

      if (templatesDir == null) {
        // Try pub cache path as last resort
        final pubCachePath = Platform.environment['PUB_CACHE'] ??
            path.join(Platform.environment['HOME'] ?? '', '.pub-cache');

        templatesDir = path.join(
          pubCachePath,
          'global_packages',
          'serverpod_vps',
          'assets',
          'templates',
          'serverpod_templates',
        );
        logger.info('Using installed assets: ${styleBold.wrap(templatesDir)}');
      } else {
        templatesDir = path.join(templatesDir, 'serverpod_templates');
        logger.info(
          'Using development assets: ${styleBold.wrap(templatesDir)}',
        );
      }

      if (!Directory(templatesDir).existsSync()) {
        throw Exception('Templates directory not found: $templatesDir');
      }

      // Copy GitHub workflows
      await _copyDirectory(
        source: path.join(templatesDir, 'github', 'workflows'),
        destination: path.join(projectDirectoryPath, '.github', 'workflows'),
        progress: progress,
      );

      // Copy server files
      final serverTemplatesDir = path.join(
        templatesDir,
        'projectname_server',
      );
      if (await Directory(serverTemplatesDir).exists()) {
        await _copyDirectory(
          source: serverTemplatesDir,
          destination: path.join(
            projectDirectoryPath,
            '${projectDirectoryName}_server',
          ),
          progress: progress,
        );
      }

      // Copy server upgrade files
      final serverUpgradeTemplatesDir = path.join(
        templatesDir,
        'projectname_server_upgrade',
      );
      if (await Directory(serverUpgradeTemplatesDir).exists()) {
        await _copyDirectory(
          source: serverUpgradeTemplatesDir,
          destination: path.join(
            projectDirectoryPath,
            '${projectDirectoryName}_server',
          ),
          progress: progress,
        );
      }

      progress.complete('Template generated successfully');
    } catch (e) {
      progress.fail('Failed to generate template');
      logger.err('Error: $e');
      exit(1);
    }
  }

  Future<void> _copyDirectory({
    required String source,
    required String destination,
    required Progress progress,
  }) async {
    final sourceDir = Directory(source);
    if (!await sourceDir.exists()) {
      logger.warn('Source directory does not exist: $source');
      return;
    }

    // Create the destination directory
    await Directory(destination).create(recursive: true);

    // Files to ignore
    final ignoreFiles = {
      // macOS system files
      '.DS_Store',
      '__MACOSX',
      '.AppleDouble',
      '.LSOverride',

      // Windows system files
      'Thumbs.db',
      'Thumbs.db:encryptable',
      'ehthumbs.db',
      'ehthumbs_vista.db',
      'desktop.ini',
      '*.lnk', // Windows shortcuts

      // Linux system files
      '.directory', // KDE directory preferences
      '.Trash-*', // KDE trash folder
      '*~', // Temporary files
      '.fuse_hidden*',
      '.nfs*',
    };

    // Copy all files
    await for (final entity in sourceDir.list(recursive: true)) {
      if (entity is File) {
        final fileName = path.basename(entity.path);
        final relativePath = path.relative(entity.path, from: source);

        // Skip system files, hidden files, and pattern matches
        if (ignoreFiles.contains(fileName) ||
            fileName.startsWith('.') ||
            ignoreFiles.any(
              (pattern) =>
                  pattern.contains('*') && _matchesPattern(fileName, pattern),
            )) {
          continue;
        }

        final destPath = path.join(destination, relativePath);

        // Create parent directories if they don't exist
        await Directory(path.dirname(destPath)).create(recursive: true);

        // Copy the file
        progress.update('Copying ${styleBold.wrap(relativePath)}');

        await entity.copy(destPath);

        logger.success('✓ Copied ${styleBold.wrap(relativePath)}');
      }
    }
  }

  bool _matchesPattern(String fileName, String pattern) {
    if (!pattern.contains('*')) return false;

    final regex = RegExp(
      '^${pattern.replaceAll('*', '.*')}\$',
      caseSensitive: false,
    );

    return regex.hasMatch(fileName);
  }

  void _printUsage() {
    logger.info('Usage: serverpod_vps');
    logger.info('Run this command in your Serverpod project directory.');
    logger.info(_argParser.usage);
  }
}
