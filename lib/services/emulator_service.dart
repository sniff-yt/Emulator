import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';
import '../models/game_profile.dart';

/// Game library and user settings.
class EmulatorService extends ChangeNotifier {
  final List<GameProfile> _games = [];
  SharedPreferences? _sp;

  // Settings
  String resolution = '1280x720';
  String renderer = 'gpu'; // default for new games and the desktop
  int fpsCap = 60;
  double controlsOpacity = 0.55;
  double buttonScale = 1.0;
  double mouseSensitivity = 1.4;
  double lookSensitivity = 1.6;
  bool haptics = true;
  String touchMode = 'trackpad'; // trackpad | direct | gamepad
  String stickKeys = 'wasd'; // wasd | arrows

  List<GameProfile> get games {
    final g = List<GameProfile>.from(_games);
    g.sort((a, b) => (b.lastPlayed ?? b.addedAt).compareTo(a.lastPlayed ?? a.addedAt));
    return List.unmodifiable(g);
  }

  Resolution get defaultResolution => Resolution.parse(resolution);

  EmulatorService() {
    _load();
  }

  Future<void> _load() async {
    final sp = _sp = await SharedPreferences.getInstance();
    final raw = sp.getString('games');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _games.addAll(list.map((e) => GameProfile.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {}
    }
    resolution = sp.getString('resolution') ?? resolution;
    renderer = sp.getString('renderer') ?? renderer;
    fpsCap = sp.getInt('fpsCap') ?? fpsCap;
    controlsOpacity = sp.getDouble('controlsOpacity') ?? controlsOpacity;
    buttonScale = sp.getDouble('buttonScale') ?? buttonScale;
    mouseSensitivity = sp.getDouble('mouseSensitivity') ?? mouseSensitivity;
    lookSensitivity = sp.getDouble('lookSensitivity') ?? lookSensitivity;
    haptics = sp.getBool('haptics') ?? haptics;
    touchMode = sp.getString('touchMode') ?? touchMode;
    stickKeys = sp.getString('stickKeys') ?? stickKeys;
    notifyListeners();
  }

  Future<void> _saveGames() async {
    await _sp?.setString('games', jsonEncode(_games.map((g) => g.toJson()).toList()));
  }

  Future<void> _saveSettings() async {
    final sp = _sp;
    if (sp == null) return;
    await sp.setString('resolution', resolution);
    await sp.setString('renderer', renderer);
    await sp.setInt('fpsCap', fpsCap);
    await sp.setDouble('controlsOpacity', controlsOpacity);
    await sp.setDouble('buttonScale', buttonScale);
    await sp.setDouble('mouseSensitivity', mouseSensitivity);
    await sp.setDouble('lookSensitivity', lookSensitivity);
    await sp.setBool('haptics', haptics);
    await sp.setString('touchMode', touchMode);
    await sp.setString('stickKeys', stickKeys);
  }

  void update(void Function(EmulatorService s) change) {
    change(this);
    _saveSettings();
    notifyListeners();
  }

  void addGame(GameProfile g) {
    _games.add(g);
    _saveGames();
    notifyListeners();
  }

  void updateGame(GameProfile g) {
    final i = _games.indexWhere((x) => x.id == g.id);
    if (i >= 0) _games[i] = g;
    _saveGames();
    notifyListeners();
  }

  void removeGame(String id) {
    _games.removeWhere((g) => g.id == id);
    _saveGames();
    notifyListeners();
  }

  void markPlayed(String id) {
    final i = _games.indexWhere((x) => x.id == id);
    if (i >= 0) updateGame(_games[i].copyWith(lastPlayed: DateTime.now()));
  }
}
