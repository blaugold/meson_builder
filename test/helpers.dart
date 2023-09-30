import 'dart:ffi';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:test/test.dart';

final fixturesDirUri = Directory('test/fixtures').absolute.uri;

/// Returns a suffix for a test that is parameterized.
///
/// [tags] represent the current configuration of the test. Each element
/// is converted to a string by calling [Object.toString].
///
/// ## Example
///
/// The instances of the test below will have the following descriptions:
///
/// - `My test`
/// - `My test (dry_run)`
///
/// ```dart
/// void main() {
///   for (final dryRun in [true, false]) {
///     final suffix = testSuffix([if (dryRun) 'dry_run']);
///
///     test('My test$suffix', () {});
///   }
/// }
/// ```
String testSuffix(List<Object> tags) => switch (tags) {
      [] => '',
      _ => ' (${tags.join(', ')})',
    };

const keepTempKey = 'KEEP_TEMPORARY_DIRECTORIES';

Future<Uri> tempDirForTest({String? prefix, bool keepTemp = false}) async {
  final tempDir = await Directory.systemTemp.createTemp(prefix);
  // Deal with Windows temp folder aliases.
  final tempUri =
      Directory(await tempDir.resolveSymbolicLinks()).uri.normalizePath();
  if ((!Platform.environment.containsKey(keepTempKey) ||
          Platform.environment[keepTempKey]!.isEmpty) &&
      !keepTemp) {
    addTearDown(() => tempDir.delete(recursive: true));
  }
  return tempUri;
}

/// Logger that outputs the full trace when a test fails.
Logger createLogger() => Logger('')
  ..level = Level.ALL
  ..onRecord.listen((record) {
    printOnFailure('${record.level.name}: ${record.time}: ${record.message}');
  });

Logger createCapturingLogger(List<String> capturedMessages) => Logger('')
  ..level = Level.ALL
  ..onRecord.listen((record) {
    printOnFailure('${record.level.name}: ${record.time}: ${record.message}');
    capturedMessages.add(record.message);
  });

/// Opens the [DynamicLibrary] at [path] and register a tear down hook to close
/// it when the current test is done.
DynamicLibrary openDynamicLibraryForTest(String path) {
  final library = DynamicLibrary.open(path);
  addTearDown(library.close);
  return library;
}
