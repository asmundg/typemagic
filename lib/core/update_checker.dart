import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const _owner = 'asmundg';
const _repo = 'typemagic';

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String releaseUrl;

  const UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseUrl,
  });

  bool get updateAvailable => latestVersion != currentVersion;
}

Future<UpdateInfo> _checkForUpdate() async {
  final packageInfo = await PackageInfo.fromPlatform();
  final current = packageInfo.version;

  final response = await http.get(
    Uri.parse(
        'https://api.github.com/repos/$_owner/$_repo/releases/latest'),
    headers: {'Accept': 'application/vnd.github.v3+json'},
  );

  if (response.statusCode != 200) {
    throw Exception(
        'GitHub API returned ${response.statusCode}: ${response.body}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final tagName = json['tag_name'] as String;
  final latest = tagName.startsWith('v') ? tagName.substring(1) : tagName;
  final htmlUrl = json['html_url'] as String;

  return UpdateInfo(
    latestVersion: latest,
    currentVersion: current,
    releaseUrl: htmlUrl,
  );
}

final updateCheckProvider = FutureProvider<UpdateInfo>((ref) async {
  return _checkForUpdate();
});
