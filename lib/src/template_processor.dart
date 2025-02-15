import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as path;

class TemplateProcessor {
  final Map<String, String> variables;
  final logger = Logger();

  TemplateProcessor(this.variables);

  String processContent(String content) {
    var processed = content;
    variables.forEach((key, value) {
      processed = processed.replaceAll('{{$key}}', value);
    });
    return processed;
  }

  Future<void> processFile(String inputPath, String outputPath) async {
    final progress = logger.progress('Processing ${path.basename(inputPath)}');

    try {
      final file = File(inputPath);
      if (!await file.exists()) {
        progress.fail('Input file does not exist: $inputPath');
        throw FileSystemException('Input file does not exist', inputPath);
      }

      final content = await file.readAsString();
      final processed = processContent(content);

      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString(processed);

      progress.complete('Processed ${path.basename(inputPath)}');
    } catch (e) {
      progress.fail('Failed to process file: ${path.basename(inputPath)}');
      rethrow;
    }
  }
}
