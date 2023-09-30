import 'dart:io';

import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';

import 'run_process.dart';

class MesonBuilder {
  MesonBuilder.library({
    required this.assetId,
    required this.project,
    required this.target,
    this.dartBuildFiles = const ['build.dart'],
  });

  final String? assetId;
  final String project;
  final String target;
  final List<String> dartBuildFiles;

  Future<void> run({
    required BuildConfig buildConfig,
    required BuildOutput buildOutput,
    required Logger? logger,
  }) async {
    // TODO: Support subdirectory targets
    // TODO: Support cross compilation

    final mesonToolUri = Uri.parse('meson');
    final packageRoot = buildConfig.packageRoot;
    final outDir = buildConfig.outDir;
    final projectUri = packageRoot.resolve(project);
    final libUri =
        outDir.resolve(buildConfig.targetOs.mesonNinjaDylibFileName(target));
    final dartBuildFiles = [
      for (final source in this.dartBuildFiles) packageRoot.resolve(source),
    ];

    switch (buildConfig.targetOs) {
      case OS.macOS:
      case OS.linux:
      case OS.windows:
        break;
      // TODO: Support other OSes
      case OS.iOS:
      case OS.android:
      case OS.fuchsia:
      default:
        throw UnimplementedError(
          'MesonBuilder does not yet support ${buildConfig.targetOs}.',
        );
    }

    if (!buildConfig.dryRun) {
      if (buildConfig.target != Target.current) {
        throw UnimplementedError(
          'MesonBuilder does not yet support cross compilation.',
        );
      }

      await Directory.fromUri(outDir).create(recursive: true);

      // Configure the build.
      await runProcess(
        executable: mesonToolUri,
        arguments: [
          'setup',
          '--reconfigure',
          // TODO: Use the Visual Studio backend on Windows
          '--backend',
          'ninja',
          '--buildtype',
          if (buildConfig.buildMode == BuildMode.release)
            'release'
          else
            'debug',
          outDir.toFilePath(),
        ],
        throwOnUnexpectedExitCode: true,
        workingDirectory: projectUri,
        logger: logger,
      );

      // Run the build.
      await runProcess(
        executable: mesonToolUri,
        arguments: [
          'compile',
          '-C',
          outDir.toFilePath(),
          target,
        ],
        throwOnUnexpectedExitCode: true,
        workingDirectory: projectUri,
        logger: logger,
      );
    }

    final targets = [
      if (!buildConfig.dryRun)
        buildConfig.target
      else
        for (final target in Target.values)
          if (target.os == buildConfig.targetOs) target
    ];
    for (final target in targets) {
      buildOutput.assets.add(Asset(
        id: assetId!,
        // TODO: Respect link preference
        linkMode: LinkMode.dynamic,
        target: target,
        path: AssetAbsolutePath(libUri),
      ));
    }

    if (!buildConfig.dryRun) {
      final projectFiles = await Directory(projectUri.toFilePath())
          .list(recursive: true)
          .where((entry) => entry is File)
          .map((file) => file.uri)
          .toList();

      buildOutput.dependencies.dependencies.addAll(projectFiles);
      buildOutput.dependencies.dependencies.addAll(dartBuildFiles);
    }
  }
}

extension on OS {
  String mesonNinjaDylibFileName(String target) {
    return switch (this) {
      // When using the Ninja backend Meson uses the the lib prefix even for
      // shared libraries on Windows.
      OS.windows => 'lib$target.dll',
      _ => dylibFileName(target),
    };
  }
}
