import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';
import 'platform.dart';
import 'remote_config.dart';

enum EngineState { checking, notInstalled, installing, ready, failed }

enum SessionState { idle, starting, running, ended }

class SetupStep {
  final int index;
  final String title;
  const SetupStep(this.index, this.title);
}

/// Owns the Linux engine: install, setup, and running sessions (desktop or a game).
class RuntimeService extends ChangeNotifier {
  EngineState state = EngineState.checking;
  SessionState session = SessionState.idle;
  double progress = 0;
  String status = '';
  String? error;
  int step = 0;
  static const totalSteps = 8;
  final List<String> logs = [];
  Map<String, String> paths = {};
  Map<String, dynamic> device = {};
  StreamSubscription? _sub;
  Completer<void>? _displayReady;
  int? lastExitCode;
  RemoteConfig? config;
  int? updateBuild;
  bool _noSeccomp = false;
  bool _prootChecked = false;

  RuntimeService() {
    _sub = NativePlatform.events.listen(_onEvent, onError: (_) {});
    _init();
  }

  bool get gpuCapable => device['kgsl'] == true;

  Future<void> _init() async {
    try {
      paths = await NativePlatform.paths();
      device = await NativePlatform.deviceInfo();
    } catch (_) {}
    final sp = await SharedPreferences.getInstance();
    _noSeccomp = sp.getBool('noSeccomp') ?? false;
    config = await RemoteConfig.load();
    await _applyConfig();
    RemoteConfig.newerBuild().then((b) {
      updateBuild = b;
      notifyListeners();
    });
    final installed = sp.getInt('setupVersion') == RuntimeConfig.setupVersion;
    final rootfs = await NativePlatform.rootfsReady().catchError((_) => false);
    state = installed && rootfs ? EngineState.ready : EngineState.notInstalled;
    notifyListeners();
  }

  void _log(String line) {
    logs.add(line);
    if (logs.length > 600) logs.removeRange(0, logs.length - 600);
  }

  void _onEvent(Map<dynamic, dynamic> e) {
    switch (e['type']) {
      case 'log':
        final line = (e['line'] ?? '').toString();
        if (line.startsWith('@@STEP ')) {
          final rest = line.substring(7);
          final sp = rest.indexOf(' ');
          step = int.tryParse(rest.substring(0, sp)) ?? step;
          status = rest.substring(sp + 1);
          progress = 0.25 + 0.75 * (step - 1) / totalSteps;
        } else if (line.startsWith('@@FAIL ')) {
          error = line.substring(7);
        } else if (line.startsWith('@@DISPLAY_READY')) {
          _displayReady?.complete();
        } else {
          _log(line);
        }
        notifyListeners();
        break;
      case 'progress':
        progress = ((e['value'] as num?)?.toDouble() ?? 0) * 0.25;
        status = (e['message'] ?? '').toString();
        notifyListeners();
        break;
      case 'exit':
        if (e['name'] == 'session') {
          lastExitCode = e['code'] as int?;
          session = SessionState.ended;
          notifyListeners();
        }
        break;
    }
  }

  Future<void> _applyConfig() async {
    final c = config;
    final env = <String, String>{...?c?.prootEnv};
    if (_noSeccomp) env['PROOT_NO_SECCOMP'] = '1';
    await NativePlatform.configure(env, c?.prootArgs ?? const []);
  }

  /// Make sure proot can start a program on this phone. If the kernel rejects
  /// proot's seccomp mode ("Function not implemented"), switch it off and retry.
  Future<void> _checkProot() async {
    if (_prootChecked) return;
    final start = logs.length;
    var code = await NativePlatform.run('true');
    final out = logs.skip(start).join('\n');
    if (code != 0 && !_noSeccomp && (config?.noSeccompFallback ?? true)) {
      _log('proot failed with seccomp on, retrying without it');
      _noSeccomp = true;
      (await SharedPreferences.getInstance()).setBool('noSeccomp', true);
      await _applyConfig();
      code = await NativePlatform.run('true');
    }
    if (code != 0) {
      throw Exception('The Linux layer (proot) could not start on this phone. ${out.split('\n').where((l) => l.contains('error')).take(2).join(' ')}');
    }
    _prootChecked = true;
  }

  /// Copy the runtime scripts from the app assets into the container.
  Future<void> _writeScripts() async {
    final root = paths['rootfs'];
    if (root == null) return;
    final dir = Directory('$root/opt/pcemu');
    await dir.create(recursive: true);
    for (final f in ['setup.sh', 'session.sh', 'env.sh', 'input_daemon.py', 'desktop_files.sh']) {
      final data = await (config ??= await RemoteConfig.load()).script(f);
      final file = File('${dir.path}/$f');
      await file.writeAsString(data);
    }
  }

  Future<void> install() async {
    if (state == EngineState.installing) return;
    state = EngineState.installing;
    error = null;
    progress = 0;
    step = 0;
    status = 'Preparing';
    logs.clear();
    notifyListeners();
    try {
      paths = await NativePlatform.paths();
      config = await RemoteConfig.load();
      await _applyConfig();
      if (!await NativePlatform.rootfsReady()) {
        await NativePlatform.installRootfs(_url('rootfsUrl', RuntimeConfig.rootfsUrl));
      }
      progress = 0.25;
      status = 'Checking Linux layer';
      notifyListeners();
      await _checkProot();
      await _writeScripts();
      final code = await NativePlatform.run(_setupCmd());
      if (code != 0) {
        throw Exception(error ?? 'Setup exited with code $code');
      }
      final sp = await SharedPreferences.getInstance();
      await sp.setInt('setupVersion', RuntimeConfig.setupVersion);
      progress = 1;
      status = 'Engine ready';
      state = EngineState.ready;
    } catch (e) {
      error ??= e.toString().replaceFirst('Exception: ', '');
      state = EngineState.failed;
    }
    notifyListeners();
  }

  /// Wipe the Windows prefix (keeps Linux + Wine), useful when a game breaks it.
  Future<int> resetWindows() async {
    await _writeScripts();
    return NativePlatform.run('rm -rf /root/.wine /opt/pcemu/state/prefix && ${_setupCmd()}');
  }

  Future<void> uninstall() async {
    await stopSession();
    final root = paths['rootfs'];
    if (root != null) {
      final d = Directory(root);
      if (await d.exists()) await d.delete(recursive: true);
    }
    final sp = await SharedPreferences.getInstance();
    await sp.remove('setupVersion');
    state = EngineState.notInstalled;
    notifyListeners();
  }

  /// Start a session and return the Flutter texture id once the display is up.
  Future<int> startSession({
    required bool desktop,
    String? exe,
    String args = '',
    required int width,
    required int height,
    required String renderer,
    int fps = 60,
  }) async {
    await stopSession();
    session = SessionState.starting;
    lastExitCode = null;
    logs.clear();
    notifyListeners();
    config = await RemoteConfig.load();
    await _applyConfig();
    await _checkProot();
    await _writeScripts();
    _displayReady = Completer<void>();
    final quoted = exe == null ? '' : _q(exe);
    final cmd = 'bash /opt/pcemu/session.sh ${desktop ? 'desktop' : 'game'} $width $height $renderer $quoted $args';
    await NativePlatform.start('session', cmd);
    await NativePlatform.keepScreenOn(true);
    await _displayReady!.future.timeout(const Duration(seconds: 40), onTimeout: () {});
    final id = await NativePlatform.displayStart(paths['framebuffer'] ?? '', width, height, fps);
    session = SessionState.running;
    notifyListeners();
    return id;
  }

  Future<void> stopSession() async {
    if (session == SessionState.idle) return;
    try {
      await NativePlatform.displayStop();
      await NativePlatform.stop('session');
      await NativePlatform.run('pkill -f wineserver; pkill -f "Xvfb :1"; pkill -f input_daemon.py; true');
      await NativePlatform.keepScreenOn(false);
    } catch (_) {}
    session = SessionState.idle;
    notifyListeners();
  }

  String _url(String key, String fallback) {
    final v = config?.str(key) ?? '';
    return v.isEmpty ? fallback : v;
  }

  String _setupCmd() => 'bash /opt/pcemu/setup.sh "${_url('wineUrl', RuntimeConfig.wineUrl)}" '
      '"${_url('dxvkUrl', RuntimeConfig.dxvkUrl)}" "${_url('mesaUrl', RuntimeConfig.mesaUrl)}"';

  Future<void> openUpdate() => NativePlatform.openUrl(RemoteConfig.apkUrl);

  static String _q(String s) => "'${s.replaceAll("'", "'\\''")}'";

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
