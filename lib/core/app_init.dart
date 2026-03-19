import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Initializes app-level services before runApp.
class AppInit {
  static const _resultsBoxName = 'test_results';

  static Future<void> initialize() async {
    // Initialize Hive storage
    if (kIsWeb) {
      Hive.init('');
    } else {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init('${dir.path}/typemagic');
    }

    await Hive.openBox(_resultsBoxName);

    // Initialize Norwegian date formatting
    await initializeDateFormatting('nb_NO');
  }
}
