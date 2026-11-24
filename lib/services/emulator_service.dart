import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_profile.dart';
import 'native_bridge.dart';
import 'dart:convert';

class EmulatorService extends ChangeNotifier {
  final List<GameProfile> _games = [];
  bool _running = false;
  GameProfile? _active;
  double _fps = 0;
  int _ramMB = 4096;
  int _cpuCores = 4;

  List<GameProfile> get games => List.unmodifiable(_games);
  bool get running => _running;
  GameProfile? get active => _active;
  double get fps => _fps;
  int get ramMB => _ramMB;
  int get cpuCores => _cpuCores;

  EmulatorService() {
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('games');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _games.addAll(list.map((e) => GameProfile.fromJson(e)));
    }
    _ramMB = sp.getInt('ram') ?? 4096;
    _cpuCores = sp.getInt('cores') ?? 4;
    notifyListeners();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('games', jsonEncode(_games.map((g) => g.toJson()).toList()));
    await sp.setInt('ram', _ramMB);
    await sp.setInt('cores', _cpuCores);
  }

  void setRam(int v) { _ramMB = v; _save(); notifyListeners(); }
  void setCores(int v) { _cpuCores = v; _save(); notifyListeners(); }

  void addGame(GameProfile g) { _games.add(g); _save(); notifyListeners(); }
  void removeGame(String id) { _games.removeWhere((g) => g.id == id); _save(); notifyListeners(); }

  Future<void> launch(GameProfile g) async {
    _active = g;
    _running = true;
    notifyListeners();
    // Emulation core hook: a real build would spawn a native isolate here
    // running the x86/ARM translation layer (box86/box64 or a custom JIT).
    _simulateLoop();
  }

  void _simulateLoop() async {
    while (_running) {
      await Future.delayed(const Duration(milliseconds: 500));
      _fps = 58 + (DateTime.now().millisecond % 4);
      notifyListeners();
    }
  }

  void stop() {
    _running = false;
    _active = null;
    _fps = 0;
    notifyListeners();
  }
}