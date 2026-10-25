import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const _owner = 'asmundg';
const _repo = 'typemagic';

/// A newer release, downloaded and unpacked, waiting to replace the running app.
class StagedUpdate {
  final String version;

  /// Temp dir holding the unpacked release and the installer's log.
  final String workDir;

  /// The running app: the .app bundle on macOS, the folder holding
  /// typemagic.exe on Windows.
  final String installPath;

  const StagedUpdate({
    required this.version,
    required this.workDir,
    required this.installPath,
  });

  String get stagedPath => Platform.isMacOS
      ? '$workDir/unpacked/typemagic.app'
      : '$workDir\\unpacked';
}

/// Whether [latest] is a higher x.y.z than [current]. Build suffixes (+n) are
/// ignored.
bool isNewerVersion(String latest, String current) {
  List<int> parse(String v) =>
      v.split('+').first.split('.').map(int.parse).toList();
  final a = parse(latest), b = parse(current);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

String _installPath() {
  final exe = File(Platform.resolvedExecutable);
  if (Platform.isWindows) return exe.parent.path;
  // typemagic.app/Contents/MacOS/typemagic
  final app = exe.parent.parent.parent.path;
  if (!app.endsWith('.app')) {
    throw StateError('Not running from a bundle: $app');
  }
  if (app.contains('/AppTranslocation/')) {
    throw StateError(
      'Flytt typemagic.app til Programmer for å få oppdateringer',
    );
  }
  return app;
}

Future<void> _run(String exe, List<String> args) async {
  final r = await Process.run(exe, args);
  if (r.exitCode != 0) {
    throw ProcessException(exe, args, '${r.stdout}${r.stderr}', r.exitCode);
  }
}

/// Checks GitHub for a newer release and, if there is one, downloads, verifies
/// and unpacks it. Returns null when already up to date.
Future<StagedUpdate?> _stageUpdate() async {
  if (kIsWeb || !kReleaseMode || !(Platform.isMacOS || Platform.isWindows)) {
    return null;
  }
  final current = (await PackageInfo.fromPlatform()).version;

  final response = await http.get(
    Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest'),
    headers: {'Accept': 'application/vnd.github.v3+json'},
  );
  if (response.statusCode != 200) {
    throw Exception(
      'GitHub API returned ${response.statusCode}: ${response.body}',
    );
  }
  final release = jsonDecode(response.body) as Map<String, dynamic>;
  final tagName = release['tag_name'] as String;
  final latest = tagName.startsWith('v') ? tagName.substring(1) : tagName;
  if (!isNewerVersion(latest, current)) return null;

  final installPath = _installPath();
  final assetName = Platform.isMacOS
      ? 'typemagic-macos.zip'
      : 'typemagic-windows.zip';
  final asset = (release['assets'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((a) => a['name'] == assetName);
  final download = await http.get(
    Uri.parse(asset['browser_download_url'] as String),
  );
  if (download.statusCode != 200) {
    throw Exception('Download of $assetName returned ${download.statusCode}');
  }
  final digest = 'sha256:${sha256.convert(download.bodyBytes)}';
  if (digest != asset['digest']) {
    throw Exception('$assetName digest $digest != ${asset['digest']}');
  }

  final workDir = await Directory.systemTemp.createTemp('typemagic-update-');
  final zip = File('${workDir.path}/$assetName');
  await zip.writeAsBytes(download.bodyBytes);
  final unpacked = await Directory('${workDir.path}/unpacked').create();
  if (Platform.isMacOS) {
    // ditto keeps the bundle's symlinks and permissions intact.
    await _run('ditto', ['-x', '-k', zip.path, unpacked.path]);
  } else {
    await _run('tar', ['-xf', zip.path, '-C', unpacked.path]);
  }
  await zip.delete();

  return StagedUpdate(
    version: latest,
    workDir: workDir.path,
    installPath: installPath,
  );
}

final updateProvider = FutureProvider<StagedUpdate?>((ref) => _stageUpdate());

// Args: pid workDir staged install relaunch. Puts the old bundle back if the
// new one cannot be moved into place.
const _macInstallScript = r'''
exec >>"$2/install.log" 2>&1
set -x
while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
rm -rf "$4.old"
mv "$4" "$4.old" || exit 1
mv "$3" "$4" || { mv "$4.old" "$4"; exit 1; }
rm -rf "$4.old"
[ "$5" = 0 ] || open "$4"
''';

String _psQuote(String s) => "'${s.replaceAll("'", "''")}'";

/// Starts a detached helper that waits for this process to exit, copies the
/// staged release over the running one and optionally starts it again. The
/// caller must exit for the helper to proceed.
Future<void> installUpdate(
  StagedUpdate update, {
  required bool relaunch,
}) async {
  if (Platform.isMacOS) {
    await Process.start('/bin/sh', [
      '-c',
      _macInstallScript,
      'sh',
      '$pid',
      update.workDir,
      update.stagedPath,
      update.installPath,
      relaunch ? '1' : '0',
    ], mode: ProcessStartMode.detached);
    return;
  }

  final script =
      '''
\$ErrorActionPreference = 'Stop'
Start-Transcript -Path ${_psQuote('${update.workDir}\\install.log')}
Wait-Process -Id $pid -ErrorAction SilentlyContinue
robocopy ${_psQuote(update.stagedPath)} ${_psQuote(update.installPath)} /E /MOVE /R:20 /W:1 /NP
if (\$LASTEXITCODE -ge 8) { throw "robocopy failed with \$LASTEXITCODE" }
${relaunch ? "Start-Process ${_psQuote('${update.installPath}\\typemagic.exe')}" : ''}
''';
  // -EncodedCommand takes base64 of UTF-16LE, which sidesteps quoting.
  final utf16 = ByteData(script.length * 2);
  for (var i = 0; i < script.length; i++) {
    utf16.setUint16(i * 2, script.codeUnitAt(i), Endian.little);
  }
  await Process.start('powershell', [
    '-NoProfile',
    '-WindowStyle',
    'Hidden',
    '-EncodedCommand',
    base64Encode(utf16.buffer.asUint8List()),
  ], mode: ProcessStartMode.detached);
}
