import 'package:flutter/services.dart';

/// Thin wrapper around the Kotlin side (Runtime.kt / Display.kt / MainActivity.kt).
class NativePlatform {
  static const _ch = MethodChannel('pcemu/runtime');
  static const _events = EventChannel('pcemu/events');

  static Stream<Map<dynamic, dynamic>> get events =>
      _events.receiveBroadcastStream().map((e) => e as Map<dynamic, dynamic>);

  static Future<Map<String, String>> paths() async =>
      Map<String, String>.from(await _ch.invokeMethod<Map>('paths') ?? {});
  static Future<bool> rootfsReady() async => await _ch.invokeMethod<bool>('rootfsReady') ?? false;
  static Future<void> installRootfs(String url) => _ch.invokeMethod('installRootfs', {'url': url});
  static Future<int> run(String cmd) async => await _ch.invokeMethod<int>('run', {'cmd': cmd}) ?? -1;
  static Future<void> start(String name, String cmd) => _ch.invokeMethod('start', {'name': name, 'cmd': cmd});
  static Future<void> stop(String name) => _ch.invokeMethod('stop', {'name': name});
  static Future<void> stopAll() => _ch.invokeMethod('stopAll');
  static Future<bool> isRunning(String name) async => await _ch.invokeMethod<bool>('isRunning', {'name': name}) ?? false;

  static Future<int> displayStart(String path, int w, int h, int fps) async =>
      await _ch.invokeMethod<int>('displayStart', {'path': path, 'width': w, 'height': h, 'fps': fps}) ?? -1;
  static Future<Map<String, int>> displayInfo() async =>
      Map<String, int>.from(await _ch.invokeMethod<Map>('displayInfo') ?? {});
  static Future<void> displayStop() => _ch.invokeMethod('displayStop');

  static Future<void> keepScreenOn(bool on) => _ch.invokeMethod('keepScreenOn', {'on': on});
  static Future<bool> hasStorage() async => await _ch.invokeMethod<bool>('hasStorage') ?? false;
  static Future<void> requestStorage() => _ch.invokeMethod('requestStorage');
  static Future<Map<String, dynamic>> deviceInfo() async =>
      Map<String, dynamic>.from(await _ch.invokeMethod<Map>('deviceInfo') ?? {});
}
