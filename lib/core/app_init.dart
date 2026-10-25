import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Initializes app-level services before runApp.
class AppInit {
  static const _resultsBoxName = 'test_results';

  static Future<void> initialize() async {
    // Initialize Hive storage
    if (kIsWeb) {
      Hive.init('');
    } else if (Platform.isMacOS) {
      // The app runs unsandboxed so it can replace itself, and an unsandboxed
      // app needs permission to touch ~/Documents.
      final dir = '${(await getApplicationSupportDirectory()).path}/typemagic';
      await _copyOutOfSandbox(dir);
      Hive.init(dir);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init('${dir.path}/typemagic');
    }

    await Hive.openBox(_resultsBoxName);

    // Initialize Norwegian date formatting
    await initializeDateFormatting('nb_NO');
  }

  /// Builds up to v0.4.0 ran sandboxed and kept their data in the app's
  /// container. Copies it to [dir] the first time an unsandboxed build starts.
  static Future<void> _copyOutOfSandbox(String dir) async {
    if (Directory(dir).existsSync()) return;
    final bundleId = (await PackageInfo.fromPlatform()).packageName;
    final container =
        '${Platform.environment['HOME']}/Library/Containers/$bundleId/Data';
    final oldHive = Directory('$container/Documents/typemagic');
    if (!oldHive.existsSync()) return;

    final prefs = File('$container/Library/Preferences/$bundleId.plist');
    if (prefs.existsSync()) {
      final r = await Process.run('defaults', ['import', bundleId, prefs.path]);
      if (r.exitCode != 0) {
        throw ProcessException(
          'defaults',
          ['import'],
          '${r.stderr}',
          r.exitCode,
        );
      }
    }
    // Copy into a side directory and rename, so a failed copy is retried on
    // the next start instead of leaving a half-filled store.
    final tmp = await Directory('$dir.copying').create(recursive: true);
    for (final f in oldHive.listSync().whereType<File>()) {
      if (f.path.endsWith('.hive')) {
        await f.copy('${tmp.path}/${f.uri.pathSegments.last}');
      }
    }
    await tmp.rename(dir);
  }
}
