import 'dart:io';

import 'package:serverpod_vps/serverpod_vps.dart';

void main(List<String> arguments) async {
  final app = TemplateGenerator();

  await app.run(arguments);
}
