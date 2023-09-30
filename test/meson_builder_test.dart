import 'dart:ffi';

import 'package:meson_builder/meson_builder.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  for (final dryRun in [true, false]) {
    for (final buildMode in BuildMode.values) {
      final suffix = testSuffix([
        if (dryRun) 'dry_run',
        buildMode,
      ]);

      test('MesonBuilder library$suffix', () async {
        const name = 'add';
        final logger = createLogger();
        final tempDir = await tempDirForTest();
        final mesonAddLibDirUri = fixturesDirUri.resolve('meson_add_lib/');

        final buildConfig = dryRun
            ? BuildConfig.dryRun(
                outDir: tempDir,
                packageRoot: mesonAddLibDirUri,
                targetOs: OS.current,
                linkModePreference: LinkModePreference.dynamic,
              )
            : BuildConfig(
                outDir: tempDir,
                packageRoot: mesonAddLibDirUri,
                targetOs: OS.current,
                linkModePreference: LinkModePreference.dynamic,
                buildMode: buildMode,
                targetArchitecture: Architecture.current,
              );
        final buildOutput = BuildOutput();

        final builder = MesonBuilder.library(
          assetId: '$name.dart',
          project: 'meson_project',
          target: name,
        );
        await builder.run(
          buildConfig: buildConfig,
          buildOutput: buildOutput,
          logger: logger,
        );

        if (dryRun) {
          expect(
            buildOutput.assets.map((asset) => asset.target),
            containsAll(Target.values.where((asset) => asset.os == OS.current)),
          );
          for (final asset in buildOutput.assets) {
            expect(await asset.path.exists(), isFalse);
          }
        } else {
          final asset = buildOutput.assets.single;
          final assetPath = asset.path as AssetAbsolutePath;
          expect(asset.target, Target.current);
          expect(await asset.path.exists(), isTrue);

          final library = openDynamicLibraryForTest(assetPath.uri.toFilePath());
          final add = library.lookupFunction<Int32 Function(Int32, Int32),
              int Function(int, int)>('add');
          expect(add(1, 2), 3);
        }
      });
    }
  }
}
