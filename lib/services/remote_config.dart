import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings that live in the GitHub repo (remote/config.json), so engine fixes
/// ship without installing a new APK. Falls back to the last good copy, then
/// to the copy bundled in the app.
class RemoteConfig {
  static const url = 'https://raw.githubusercontent.com/sniff-yt/Emulator/main/remote/config.json';
  static const releaseApi = 'https://api.github.com/repos/sniff-yt/Emulator/releases/tags/latest';
  static const apkUrl = 'https://github.com/sniff-yt/Emulator/releases/download/latest/PC-Emulator.apk';
  static const buildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);

  final Map<String, dynamic> data;
  final String source; // remote | cache | bundled
  RemoteConfig(this.data, this.source);

  String str(String k) => (data[k] ?? '').toString();
  Map<String, String> get prootEnv =>
      Map<String, dynamic>.from(data['prootEnv'] as Map? ?? {}).map((k, v) => MapEntry(k, v.toString()));
  List<String> get prootArgs => List<dynamic>.from(data['prootArgs'] as List? ?? []).map((e) => e.toString()).toList();
  bool get noSeccompFallback => data['noSeccompFallback'] != false;
  String get scriptsBase => str('scriptsBase');

  static Future<String?> fetchText(String u, {Duration timeout = const Duration(seconds: 8)}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(Uri.parse(u)).timeout(timeout);
      req.headers.set('Cache-Control', 'no-cache');
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return null;
      return await res.transform(utf8.decoder).join().timeout(timeout);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<RemoteConfig> load() async {
    final sp = await SharedPreferences.getInstance();
    final remote = await fetchText('$url?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}');
    if (remote != null) {
      try {
        final m = jsonDecode(remote) as Map<String, dynamic>;
        await sp.setString('remoteConfig', remote);
        return RemoteConfig(m, 'remote');
      } catch (_) {}
    }
    final cached = sp.getString('remoteConfig');
    if (cached != null) {
      try {
        return RemoteConfig(jsonDecode(cached) as Map<String, dynamic>, 'cache');
      } catch (_) {}
    }
    final bundled = await rootBundle.loadString('assets/remote_config.json');
    return RemoteConfig(jsonDecode(bundled) as Map<String, dynamic>, 'bundled');
  }

  /// Get a runtime script: latest from the repo, else bundled.
  Future<String> script(String name) async {
    if (scriptsBase.isNotEmpty) {
      final t = await fetchText('$scriptsBase$name?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}');
      if (t != null && t.length > 20) return t;
    }
    return rootBundle.loadString('assets/runtime/$name');
  }

  /// Returns the newer build number if the 'latest' release is newer than this app.
  static Future<int?> newerBuild() async {
    final t = await fetchText(releaseApi);
    if (t == null) return null;
    try {
      final body = ((jsonDecode(t) as Map)['body'] ?? '').toString();
      final m = RegExp(r'build (\d+)').firstMatch(body);
      final n = m == null ? 0 : int.parse(m.group(1)!);
      return n > buildNumber ? n : null;
    } catch (_) {
      return null;
    }
  }
}
