import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves screenshots taken by integration_test/screenshots_test.dart to
/// $SCREENSHOT_DIR (default: build/screenshots).
Future<void> main() async {
  final outDir = Platform.environment['SCREENSHOT_DIR'] ?? 'build/screenshots';
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('$outDir/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
