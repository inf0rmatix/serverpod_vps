import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final dockerfile = File(
    'lib/assets/templates/serverpod_templates/projectname_server/Dockerfile.prod',
  ).readAsStringSync();

  group(
    'Production Dockerfile shell behavior',
    () {
      test('entrypoint passes default environment and migration arguments',
          () async {
        final entrypointLine = dockerfile
            .split('\n')
            .singleWhere((line) => line.startsWith('ENTRYPOINT '));
        final entrypoint =
            (jsonDecode(entrypointLine.substring(11)) as List).cast<String>();
        final environment = <String, String>{
          for (final match in RegExp(r'^ENV (\w+)=(.*)$', multiLine: true)
              .allMatches(dockerfile))
            match.group(1)!: match.group(2)!,
        };
        final arguments = entrypoint.skip(1).toList();
        arguments[1] = arguments[1].replaceFirst(
          'exec ./bin/server',
          r"printf '%s\n'",
        );

        final result = await Process.run(
          entrypoint.first,
          [...arguments, '--apply-migrations', '--example=two words'],
          environment: environment,
        );

        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(const LineSplitter().convert(result.stdout as String), [
          '--mode=production',
          '--server-id=default',
          '--logging=normal',
          '--role=monolith',
          '--apply-migrations',
          '--example=two words',
        ]);

        final overriddenResult = await Process.run(
          entrypoint.first,
          arguments,
          environment: {...environment, 'serverid': 'server with spaces'},
        );

        expect(
          overriddenResult.exitCode,
          0,
          reason: '${overriddenResult.stderr}',
        );
        expect(
            const LineSplitter().convert(overriddenResult.stdout as String), [
          '--mode=production',
          '--server-id=server with spaces',
          '--logging=normal',
          '--role=monolith',
        ]);
      });

      for (final hasWorkspaceResolution in [true, false]) {
        test(
            hasWorkspaceResolution
                ? 'workspace rewrite excludes Flutter and retains root lockfile'
                : 'standalone project retains original pubspec and lockfiles',
            () async {
          final directory = await Directory.systemTemp.createTemp(
            'serverpod_vps_dockerfile_',
          );
          final serverDirectory = await Directory(
            '${directory.path}/projectname_server',
          ).create();
          const rootPubspec = '''
name: original_workspace
environment:
  sdk: ^3.12.2
workspace:
  - projectname_server
  - projectname_client
  - projectname_flutter
''';
          final serverPubspec = '''
name: projectname_server
environment:
  sdk: ^3.12.2
${hasWorkspaceResolution ? 'resolution: workspace' : ''}
dependencies:
  serverpod: 4.0.0
''';
          final rootPubspecFile = File('${directory.path}/pubspec.yaml');
          final rootLockfile = File('${directory.path}/pubspec.lock');
          final serverPubspecFile =
              File('${serverDirectory.path}/pubspec.yaml');
          final serverLockfile = File('${serverDirectory.path}/pubspec.lock');
          await rootPubspecFile.writeAsString(rootPubspec);
          await rootLockfile.writeAsString('root lockfile fixture\n');
          await serverPubspecFile.writeAsString(serverPubspec);
          await serverLockfile.writeAsString('server lockfile fixture\n');

          final instructionStart = dockerfile.indexOf('RUN if grep -Eq');
          final instructionEnd = dockerfile.indexOf('\n\n', instructionStart);
          final workspaceInstruction = dockerfile
              .substring(instructionStart + 4, instructionEnd)
              .replaceAll('\\\n', ' ');
          final result = await Process.run(
            '/bin/sh',
            ['-eu', '-c', workspaceInstruction],
            workingDirectory: directory.path,
          );

          expect(result.exitCode, 0, reason: '${result.stderr}');
          expect(await rootLockfile.readAsString(), 'root lockfile fixture\n');
          expect(
            await serverLockfile.readAsString(),
            'server lockfile fixture\n',
          );
          expect(await serverPubspecFile.readAsString(), serverPubspec);

          if (!hasWorkspaceResolution) {
            expect(await rootPubspecFile.readAsString(), rootPubspec);
            return;
          }

          final pubspec =
              loadYaml(await rootPubspecFile.readAsString()) as YamlMap;

          expect(pubspec['workspace'], ['projectname_server']);
          expect(pubspec['environment']['sdk'], '^3.12.2');
        });
      }
    },
    skip: Platform.isWindows ? 'Requires a POSIX shell.' : false,
  );
}
