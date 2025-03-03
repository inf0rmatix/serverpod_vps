import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// Generator for Serverpod VPS deployment files.
/// Takes a Serverpod project and adds necessary files for VPS deployment.
class TemplateGenerator {
  late final ArgParser _argParser;
  final _logger = Logger();

  /// The name of the project directory.
  late final String projectDirectoryName;

  /// The path to the project directory.
  late final String projectDirectoryPath;

  /// The email address to use for SSL certificate notifications.
  late final String userEmail;

  /// The list of files that have been copied.
  final _copiedFiles = <String>[];

  TemplateGenerator() {
    _initializeArgParser();
  }

  /// Initialize the argument parser with available options
  void _initializeArgParser() {
    _argParser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        help: 'Show this help message',
        negatable: false,
      );
  }

  /// Main entry point for the generator
  Future<void> run(List<String> arguments) async {
    try {
      final results = _argParser.parse(arguments);

      if (results['help'] as bool) {
        _printUsage();
        return;
      }

      _printWelcomeMessage();

      // Validate project structure
      if (!await checkDirectoryStructure()) {
        exit(1);
      }

      _printProjectInfo();

      // Get user input
      userEmail = await _promptEmail();

      // Generate deployment files
      await _generateTemplate();
    } catch (e) {
      _logger.err('Error: $e');
      _printUsage();
      exit(1);
    }
  }

  /// Print welcome banner
  void _printWelcomeMessage() {
    _logger.info('');
    _logger.info(
      backgroundBlue.wrap(
        white.wrap(
          '\t========================================================\t',
        ),
      ),
    );
    _logger.info(
      backgroundBlue.wrap(
        white.wrap('\t\t  🚀 Serverpod VPS Deployment Generator\t\t\t'),
      ),
    );
    _logger.info(
      backgroundBlue.wrap(
        white.wrap(
          '\t========================================================\t',
        ),
      ),
    );
    _logger.info('');
  }

  /// Print current project information
  void _printProjectInfo() {
    _logger.info(
      'Project directory: ${styleBold.wrap(projectDirectoryPath)}',
    );
    _logger.info(
      'Project directory name: ${styleBold.wrap(projectDirectoryName)}',
    );
  }

  /// Check if the current directory has the expected Serverpod project structure
  @visibleForTesting
  Future<bool> checkDirectoryStructure() async {
    _initializeProjectPaths();

    _logger.info(
      'Checking directory structure in: $projectDirectoryPath',
    );

    return await _validateRequiredDirectories();
  }

  /// Initialize project paths from current directory
  void _initializeProjectPaths() {
    projectDirectoryPath = Directory.current.absolute.path;
    projectDirectoryName = findProjectName();
  }

  /// Find project name by looking at _server and _client directory names
  @visibleForTesting
  String findProjectName() {
    final currentDir = Directory.current;
    final contents = currentDir.listSync();

    String? serverDirName;
    String? clientDirName;

    for (final entity in contents) {
      if (entity is! Directory) {
        continue;
      }

      final name = path.basename(entity.path);

      const serverSuffix = '_server';
      const clientSuffix = '_client';

      if (name.endsWith(serverSuffix)) {
        serverDirName = name.substring(0, name.length - serverSuffix.length);
      } else if (name.endsWith(clientSuffix)) {
        clientDirName = name.substring(0, name.length - clientSuffix.length);
      }

      if (serverDirName != null && clientDirName != null) {
        break;
      }
    }

    // Verify both directories exist and have matching names
    if (serverDirName != null &&
        clientDirName != null &&
        serverDirName == clientDirName) {
      return serverDirName;
    }

    throw Exception(
      'Could not determine project name. Ensure you have matching '
      'projectname_server and projectname_client directories.',
    );
  }

  /// Validate that required project directories exist
  Future<bool> _validateRequiredDirectories() async {
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
      _printMissingDirectoryError('server');
      return false;
    }

    if (!await clientDir.exists()) {
      _printMissingDirectoryError('client');
      return false;
    }

    _logger.success('Directory structure is valid');
    return true;
  }

  /// Print error message for missing directory
  void _printMissingDirectoryError(String dirType) {
    _logger.err('Missing $dirType directory: ${projectDirectoryName}_$dirType');
    _logger.info('Expected directory structure:');
    _logger.info('  $projectDirectoryName/');
    _logger.info('  ├── ${projectDirectoryName}_server/');
    _logger.info('  └── ${projectDirectoryName}_client/');
  }

  /// Main template generation logic
  Future<void> _generateTemplate() async {
    _logger.success('Generating files for project: $projectDirectoryName');
    _logger.detail('Project directory: $projectDirectoryPath');

    final progress = _logger.progress('Generating');
    _copiedFiles.clear();

    try {
      final templatesDir = await _resolveTemplatesDirectory();
      await _generateDeploymentFiles(templatesDir, progress);

      progress.complete('Files generated successfully');
      _printGeneratedFilesSummary();
    } catch (error) {
      progress.fail('Failed to generate template');
      _logger.err('Error: $error');
      exit(1);
    }
  }

  /// Resolve the templates directory path
  Future<String> _resolveTemplatesDirectory() async {
    // Resolve package URI to get the templates directory
    final templateUri = await Isolate.resolvePackageUri(
      Uri.parse('package:serverpod_vps/assets/templates/serverpod_templates'),
    );

    if (templateUri == null) {
      throw Exception('Could not resolve templates directory');
    }

    final templatesDir = path.fromUri(templateUri);
    _logger.info('Using installed assets: ${styleBold.wrap(templatesDir)}');

    if (!Directory(templatesDir).existsSync()) {
      throw Exception('Templates directory not found: $templatesDir');
    }

    return templatesDir;
  }

  /// Generate all deployment files from templates
  Future<void> _generateDeploymentFiles(
    String templatesDir,
    Progress progress,
  ) async {
    // Copy GitHub workflows
    await _copyDirectory(
      source: path.join(templatesDir, 'github', 'workflows'),
      destination: path.join(projectDirectoryPath, '.github', 'workflows'),
      progress: progress,
    );

    // Copy server files
    await _copyServerFiles(templatesDir, progress);
  }

  /// Copy server-specific files
  Future<void> _copyServerFiles(String templatesDir, Progress progress) async {
    final serverDestination = path.join(
      projectDirectoryPath,
      '${projectDirectoryName}_server',
    );

    // Copy base server files
    final serverTemplatesDir = path.join(
      templatesDir,
      'projectname_server',
    );
    if (await Directory(serverTemplatesDir).exists()) {
      await _copyDirectory(
        source: serverTemplatesDir,
        destination: serverDestination,
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
        destination: serverDestination,
        progress: progress,
      );
    }
  }

  /// Print summary of all generated files
  void _printGeneratedFilesSummary() {
    _logger.info('');
    _logger.info(styleBold.wrap('Files generated:'));
    for (final file in _copiedFiles) {
      _logger.info('  ${styleBold.wrap('•')} $file');
    }
    _logger.info('');
  }

  Future<void> _copyDirectory({
    required String source,
    required String destination,
    required Progress progress,
  }) async {
    final sourceDir = Directory(source);
    if (!await sourceDir.exists()) {
      _logger.warn('Source directory does not exist: $source');
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

        // Read file content and replace placeholders
        var content = await entity.readAsString();
        content = content
            .replaceAll('{{ACME_EMAIL}}', userEmail)
            .replaceAll('projectname', projectDirectoryName);

        // Create parent directories if they don't exist
        await Directory(path.dirname(destPath)).create(recursive: true);

        // Write modified content
        progress.update('Copying ${styleBold.wrap(relativePath)}');
        await File(destPath).writeAsString(content);

        // Track the copied file (relative to project root)
        final relativeToRoot = path.relative(
          destPath,
          from: projectDirectoryPath,
        );
        _copiedFiles.add(relativeToRoot);
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

  Future<String> _promptEmail() async {
    while (true) {
      final email = _logger.prompt(
        'Enter your email address for SSL certificate notifications:',
        defaultValue: '',
      );

      if (_isValidEmail(email)) {
        return email;
      }

      _logger.err('Please enter a valid email address.');
    }
  }

  bool _isValidEmail(String email) {
    // Check for @ with text before and after
    final atIndex = email.indexOf('@');
    if (atIndex <= 0 || atIndex == email.length - 1) {
      return false;
    }

    // Check for . in second part with text before and after
    final afterAt = email.substring(atIndex + 1);
    final dotIndex = afterAt.indexOf('.');
    if (dotIndex <= 0 || dotIndex == afterAt.length - 1) {
      return false;
    }

    return true;
  }

  void _printUsage() {
    _logger.info('Usage: serverpod_vps');
    _logger.info('Run this command in your Serverpod project directory.');
    _logger.info(_argParser.usage);
  }
}
