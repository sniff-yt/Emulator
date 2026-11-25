import 'dart:async';
import 'dart:io';
import '../core/config.dart';

/// Sends mouse and keyboard events to input_daemon.py inside the container.
class InputClient {
  Socket? _sock;
  bool _connecting = false;
  final Set<String> _held = {};

  bool get connected => _sock != null;

  Future<bool> connect({int attempts = 40}) async {
    if (_sock != null || _connecting) return _sock != null;
    _connecting = true;
    for (var i = 0; i < attempts; i++) {
      try {
        final s = await Socket.connect(InternetAddress.loopbackIPv4, RuntimeConfig.inputPort,
            timeout: const Duration(seconds: 1));
        s.setOption(SocketOption.tcpNoDelay, true);
        s.done.catchError((_) {}).whenComplete(() {
          if (identical(_sock, s)) _sock = null;
        });
        _sock = s;
        _connecting = false;
        return true;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    _connecting = false;
    return false;
  }

  void _send(String line) {
    final s = _sock;
    if (s == null) {
      connect(attempts: 3);
      return;
    }
    try {
      s.write('$line\n');
    } catch (_) {
      _sock = null;
    }
  }

  void moveTo(double x, double y) => _send('m ${x.round()} ${y.round()}');
  void moveBy(double dx, double dy) {
    final ix = dx.round(), iy = dy.round();
    if (ix != 0 || iy != 0) _send('r $ix $iy');
  }

  void button(int b, bool down) => _send('b $b ${down ? 1 : 0}');
  void click(int b) {
    button(b, true);
    button(b, false);
  }

  void scroll(int steps) {
    final b = steps > 0 ? 5 : 4;
    for (var i = 0; i < steps.abs(); i++) {
      click(b);
    }
  }

  void key(String name, bool down) {
    if (down) {
      _held.add(name);
    } else {
      _held.remove(name);
    }
    _send('k $name ${down ? 1 : 0}');
  }

  void tap(String name) {
    key(name, true);
    key(name, false);
  }

  void text(String t) {
    if (t.isEmpty) return;
    _send('t ${t.replaceAll('\n', '')}');
  }

  void releaseAll() {
    for (final k in _held.toList()) {
      key(k, false);
    }
    for (final b in [1, 2, 3]) {
      button(b, false);
    }
  }

  Future<void> close() async {
    releaseAll();
    try {
      await _sock?.flush();
      await _sock?.close();
    } catch (_) {}
    _sock = null;
  }
}
