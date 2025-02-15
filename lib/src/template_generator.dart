import 'dart:io';

import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';

class TemplateGenerator {
  late final ArgParser _argParser;
  final logger = Logger();

  TemplateGenerator() {
    _argParser = ArgParser()
      ..addOption(
        'project-name',
        abbr: 'p',
        help: 'Name of the project',
        mandatory: true,
      )
      ..addOption(
        'output-dir',
        abbr: 'o',
        help: 'Output directory for generated files',
        defaultsTo: '.',
      )
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

      if (results['help']) {
        _printUsage();
        return;
      }

      final projectName = results['project-name'];
      final outputDir = results['output-dir'];

      await _generateTemplate(projectName, outputDir);
    } catch (e) {
      logger.err('Error: $e');
      _printUsage();
      exit(1);
    }
  }

  Future<void> _generateTemplate(String projectName, String outputDir) async {
    logger.success('Generating template for project: ${projectName}');
    logger.detail('Output directory: ${outputDir}');

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
    logger.info('Usage: serverpod_vps [options]');
    logger.info(_argParser.usage);
  }
}
