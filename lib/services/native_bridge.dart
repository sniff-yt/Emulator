import 'dart:ffi';
import 'package:flutter/services.dart';

class NativeBridge {
  static const _channel = MethodChannel('pc_emulator/native');

  static Future<String> hello() async {
    return await _channel.invokeMethod<String>('hello') ?? '';
  }

  static Future<int> initEngine(String gamePath, {int ramMB = 2048, int cores = 2}) async {
    return await _channel.invokeMethod<int>('initEngine', {
          'gamePath': gamePath,
          'ramMB': ramMB,
          'cores': cores,
        }) ??
        -1;
  }

  static Future<void> stopEngine() async {
    await _channel.invokeMethod('stopEngine');
  }
}