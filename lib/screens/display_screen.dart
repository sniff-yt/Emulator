import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/game_profile.dart';
import '../services/emulator_service.dart';
import '../services/input_client.dart';
import '../services/platform.dart';
import '../services/runtime_service.dart';
import '../widgets/joystick.dart';
import '../widgets/pad_button.dart';

/// Full-screen view of the Linux/Windows display with touch, gamepad and keyboard controls.
class DisplayScreen extends StatefulWidget {
  final GameProfile? game; // null = Linux desktop
  const DisplayScreen({super.key, this.game});

  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  late final RuntimeService _rt;
  late final EmulatorService _app;
  final InputClient _input = InputClient();
  int? _textureId;
  int _w = 1280, _h = 720;
  int _fps = 0;
  Timer? _fpsTimer;
  String _mode = 'trackpad';
  bool _showKeys = false;
  bool _showToolbar = true;
  String? _startError;

  // keyboard (IME)
  final _imeCtrl = TextEditingController(text: ' ');
  final _imeFocus = FocusNode();

  // pointer state
  Offset _cursor = Offset.zero;
  final Map<int, Offset> _pointers = {};
  final Map<int, Offset> _downPos = {};
  DateTime _downAt = DateTime.now();
  bool _moved = false;
  bool _dragging = false;
  Timer? _longPress;
  double _scrollAcc = 0;
  int _maxPointers = 0;
  Rect _view = Rect.zero;

  // sticky modifiers
  final Set<String> _mods = {};
  // joystick keys held
  final Set<String> _stickHeld = {};

  @override
  void initState() {
    super.initState();
    _rt = context.read<RuntimeService>();
    _app = context.read<EmulatorService>();
    _mode = widget.game == null && _app.touchMode == 'gamepad' ? 'trackpad' : _app.touchMode;
    if (widget.game != null && _app.touchMode == 'trackpad') _mode = 'trackpad';
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final g = widget.game;
    final res = g?.resolution ?? _app.resolution;
    final p = res.split('x');
    _w = int.parse(p[0]);
    _h = int.parse(p[1]);
    _cursor = Offset(_w / 2, _h / 2);
    try {
      final id = await _rt.startSession(
        desktop: g == null,
        exe: g?.containerPath,
        args: g?.args ?? '',
        width: _w,
        height: _h,
        renderer: g?.renderer ?? _app.renderer,
        fps: _app.fpsCap,
      );
      if (g != null) _app.markPlayed(g.id);
      if (!mounted) return;
      setState(() => _textureId = id);
      _input.connect();
      _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
        final info = await NativePlatform.displayInfo();
        if (mounted) {
          setState(() {
            _fps = info['fps'] ?? 0;
            final w = info['width'] ?? 0, h = info['height'] ?? 0;
            if (w > 0 && h > 0 && (w != _w || h != _h)) {
              _w = w;
              _h = h;
            }
          });
        }
      });
    } catch (e) {
      if (mounted) setState(() => _startError = e.toString());
    }
  }

  @override
  void dispose() {
    _fpsTimer?.cancel();
    _longPress?.cancel();
    _input.close();
    _rt.stopSession();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([]);
    _imeCtrl.dispose();
    _imeFocus.dispose();
    super.dispose();
  }

  // ---------- coordinate mapping ----------
  Offset _toX(Offset local) {
    if (_view.width <= 0) return _cursor;
    final x = ((local.dx - _view.left) / _view.width * _w).clamp(0.0, _w - 1.0);
    final y = ((local.dy - _view.top) / _view.height * _h).clamp(0.0, _h - 1.0);
    return Offset(x, y);
  }

  double get _scale => _view.width > 0 ? _w / _view.width : 1;

  void _haptic() {
    if (_app.haptics) HapticFeedback.selectionClick();
  }

  // ---------- touch handling ----------
  void _onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    _downPos[e.pointer] = e.localPosition;
    _maxPointers = _pointers.length > _maxPointers ? _pointers.length : _maxPointers;
    if (_pointers.length == 1) {
      _downAt = DateTime.now();
      _moved = false;
      _scrollAcc = 0;
      if (_mode == 'direct') {
        _cursor = _toX(e.localPosition);
        _input.moveTo(_cursor.dx, _cursor.dy);
        _input.button(1, true);
        _dragging = true;
      } else if (_mode == 'trackpad') {
        _longPress?.cancel();
        _longPress = Timer(const Duration(milliseconds: 420), () {
          if (!_moved && _pointers.length == 1) {
            _dragging = true;
            _haptic();
            _input.button(1, true);
          }
        });
      }
    } else {
      _longPress?.cancel();
      if (_mode == 'direct' && _dragging) {
        _input.button(1, false);
        _dragging = false;
      }
    }
  }

  void _onMove(PointerMoveEvent e) {
    final prev = _pointers[e.pointer];
    if (prev == null) return;
    _pointers[e.pointer] = e.localPosition;
    final start = _downPos[e.pointer] ?? e.localPosition;
    if ((e.localPosition - start).distance > 8) _moved = true;
    final d = e.localPosition - prev;
    if (_pointers.length >= 2) {
      // two-finger scroll
      _scrollAcc += d.dy / _pointers.length;
      while (_scrollAcc.abs() > 28) {
        _input.scroll(_scrollAcc > 0 ? -1 : 1);
        _scrollAcc += _scrollAcc > 0 ? -28 : 28;
      }
      return;
    }
    switch (_mode) {
      case 'direct':
        _cursor = _toX(e.localPosition);
        _input.moveTo(_cursor.dx, _cursor.dy);
        break;
      case 'trackpad':
        final s = _scale * _app.mouseSensitivity;
        _cursor = Offset((_cursor.dx + d.dx * s).clamp(0, _w - 1.0), (_cursor.dy + d.dy * s).clamp(0, _h - 1.0));
        _input.moveTo(_cursor.dx, _cursor.dy);
        setState(() {});
        break;
      case 'gamepad':
        _input.moveBy(d.dx * _app.lookSensitivity, d.dy * _app.lookSensitivity);
        break;
    }
  }

  void _onUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    _downPos.remove(e.pointer);
    if (_pointers.isNotEmpty) return;
    _longPress?.cancel();
    final quick = DateTime.now().difference(_downAt).inMilliseconds < 260;
    if (_dragging) {
      _input.button(1, false);
      _dragging = false;
    } else if (!_moved && quick) {
      if (_maxPointers >= 2) {
        _input.click(3);
        _haptic();
      } else if (_mode == 'trackpad' || _mode == 'gamepad') {
        _input.click(1);
      }
    } else if (_mode == 'direct' && _maxPointers >= 2 && !_moved) {
      _input.click(3);
    }
    _maxPointers = 0;
  }

  // ---------- keyboard ----------
  void _openKeyboard() {
    if (_imeFocus.hasFocus) {
      _imeFocus.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } else {
      _imeFocus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }
  }

  void _onImeChanged(String v) {
    if (v.length < 1) {
      _tapKey('BackSpace');
    } else if (v.length > 1) {
      final added = v.substring(1);
      if (_mods.isNotEmpty) {
        for (final ch in added.split('')) {
          _tapKey(ch == ' ' ? 'space' : ch.toLowerCase());
        }
      } else {
        _input.text(added);
      }
    }
    _imeCtrl.value = const TextEditingValue(text: ' ', selection: TextSelection.collapsed(offset: 1));
  }

  void _tapKey(String k) {
    for (final m in _mods) {
      _input.key(m, true);
    }
    _input.tap(k);
    if (_mods.isNotEmpty) {
      for (final m in _mods) {
        _input.key(m, false);
      }
      setState(() => _mods.clear());
    }
  }

  void _toggleMod(String m) {
    setState(() {
      if (!_mods.remove(m)) _mods.add(m);
    });
    _haptic();
  }

  // ---------- gamepad ----------
  void _onStick(Offset v) {
    final keys = _app.stickKeys == 'arrows'
        ? {'up': 'Up', 'down': 'Down', 'left': 'Left', 'right': 'Right'}
        : {'up': 'w', 'down': 's', 'left': 'a', 'right': 'd'};
    final want = <String>{
      if (v.dy < -0.38) keys['up']!,
      if (v.dy > 0.38) keys['down']!,
      if (v.dx < -0.38) keys['left']!,
      if (v.dx > 0.38) keys['right']!,
    };
    for (final k in _stickHeld.difference(want)) {
      _input.key(k, false);
    }
    for (final k in want.difference(_stickHeld)) {
      _input.key(k, true);
    }
    _stickHeld
      ..clear()
      ..addAll(want);
  }

  Widget _keyBtn(String label, String key, {Color c = AppColors.cyan, double s = 1}) => PadButton(
        label: label,
        color: c,
        size: 56 * _app.buttonScale * s,
        opacity: _app.controlsOpacity,
        haptics: _app.haptics,
        onDown: () => _input.key(key, true),
        onUp: () => _input.key(key, false),
      );

  Widget _mouseBtn(String label, int b, {Color c = AppColors.red, String? sub, bool round = false}) => PadButton(
        label: label,
        sub: sub,
        round: round,
        color: c,
        size: 56 * _app.buttonScale,
        opacity: _app.controlsOpacity,
        haptics: _app.haptics,
        onDown: () => _input.button(b, true),
        onUp: () => _input.button(b, false),
      );

  Widget _gamepad() {
    final bs = _app.buttonScale;
    return Stack(children: [
      // Left stick (movement)
      Positioned(
        left: 28,
        bottom: 28,
        child: Joystick(size: 160 * bs, opacity: _app.controlsOpacity, onChanged: _onStick, label: _app.stickKeys == 'arrows' ? 'ARROWS' : 'WASD'),
      ),
      Positioned(left: 36, bottom: 200 * bs, child: _keyBtn('RUN', 'Shift_L', c: AppColors.amber, s: 0.85)),
      Positioned(left: 110 * bs, bottom: 200 * bs, child: _keyBtn('Q', 'q', c: AppColors.violet, s: 0.85)),
      // Shoulders / triggers
      Positioned(right: 24, top: 70, child: Row(children: [
        _mouseBtn('LT', 3, c: AppColors.violet, sub: 'Aim'),
        const SizedBox(width: 10),
        _mouseBtn('RT', 1, c: AppColors.red, sub: 'Fire'),
      ])),
      // Face buttons
      Positioned(
        right: 28,
        bottom: 34,
        child: SizedBox(
          width: 190 * bs,
          height: 190 * bs,
          child: Stack(children: [
            Align(alignment: Alignment.topCenter, child: _faceBtn('Y', 'e', AppColors.amber, 'Use')),
            Align(alignment: Alignment.centerLeft, child: _faceBtn('X', 'r', AppColors.cyan, 'Reload')),
            Align(alignment: Alignment.centerRight, child: _faceBtn('B', 'Control_L', AppColors.red, 'Crouch')),
            Align(alignment: Alignment.bottomCenter, child: _faceBtn('A', 'space', AppColors.green, 'Jump')),
          ]),
        ),
      ),
      Positioned(right: 230 * bs, bottom: 30, child: _keyBtn('F', 'f', c: AppColors.violet, s: 0.85)),
      // Start / select
      Positioned(
        bottom: 18,
        left: 0,
        right: 0,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _pill('TAB', 'Tab'),
          const SizedBox(width: 10),
          _pill('ESC', 'Escape'),
          const SizedBox(width: 10),
          _pill('ENTER', 'Return'),
          const SizedBox(width: 10),
          _pill('1', '1'),
          _pill('2', '2'),
          _pill('3', '3'),
        ]),
      ),
    ]);
  }

  Widget _faceBtn(String l, String k, Color c, String sub) => PadButton(
        label: l,
        sub: sub,
        color: c,
        size: 62 * _app.buttonScale,
        opacity: _app.controlsOpacity,
        haptics: _app.haptics,
        onDown: () => _input.key(k, true),
        onUp: () => _input.key(k, false),
      );

  Widget _pill(String l, String k) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: PadButton(
          label: l,
          round: false,
          color: Colors.white54,
          size: 46 * _app.buttonScale,
          opacity: _app.controlsOpacity,
          haptics: _app.haptics,
          onDown: () => _input.key(k, true),
          onUp: () => _input.key(k, false),
        ),
      );

  // ---------- key bar ----------
  Widget _keyBar() {
    Widget k(String l, String key) => _barKey(l, onTap: () => _tapKey(key));
    Widget m(String l, String key) => _barKey(l, active: _mods.contains(key), onTap: () => _toggleMod(key));
    return Container(
      height: 48,
      color: Colors.black.withOpacity(0.75),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          k('Esc', 'Escape'),
          k('Tab', 'Tab'),
          m('Ctrl', 'Control_L'),
          m('Alt', 'Alt_L'),
          m('Shift', 'Shift_L'),
          m('Win', 'Super_L'),
          k('↑', 'Up'),
          k('↓', 'Down'),
          k('←', 'Left'),
          k('→', 'Right'),
          k('Enter', 'Return'),
          k('⌫', 'BackSpace'),
          k('Del', 'Delete'),
          k('Space', 'space'),
          for (var i = 1; i <= 12; i++) k('F$i', 'F$i'),
          k('Home', 'Home'),
          k('End', 'End'),
          k('PgUp', 'Prior'),
          k('PgDn', 'Next'),
          _barKey('Alt+F4', onTap: () {
            _input.key('Alt_L', true);
            _input.tap('F4');
            _input.key('Alt_L', false);
          }),
        ],
      ),
    );
  }

  Widget _barKey(String l, {required VoidCallback onTap, bool active = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: active ? AppColors.violet : AppColors.surface2,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              _haptic();
              onTap();
            },
            child: Container(
              constraints: const BoxConstraints(minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              child: Text(l, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ),
      );

  // ---------- toolbar ----------
  Widget _toolbar() {
    final modeIcon = {'trackpad': Icons.mouse, 'direct': Icons.touch_app, 'gamepad': Icons.sports_esports}[_mode]!;
    final modeLabel = {'trackpad': 'Mouse', 'direct': 'Touch', 'gamepad': 'Gamepad'}[_mode]!;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      offset: _showToolbar ? Offset.zero : const Offset(0, -1.4),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _tb(Icons.close, 'Exit', _confirmExit),
            _tb(modeIcon, modeLabel, () {
              final order = ['trackpad', 'direct', 'gamepad'];
              setState(() => _mode = order[(order.indexOf(_mode) + 1) % order.length]);
              _input.releaseAll();
              _haptic();
            }),
            _tb(Icons.keyboard, 'Type', _openKeyboard),
            _tb(Icons.keyboard_command_key, 'Keys', () => setState(() => _showKeys = !_showKeys), active: _showKeys),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('$_fps FPS',
                  style: TextStyle(
                      color: _fps >= 30 ? AppColors.green : (_fps >= 15 ? AppColors.amber : AppColors.red),
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
            _tb(Icons.expand_less, 'Hide', () => setState(() => _showToolbar = false)),
          ]),
        ),
      ),
    );
  }

  Widget _tb(IconData i, String tip, VoidCallback onTap, {bool active = false}) => IconButton(
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        icon: Icon(i, size: 20, color: active ? AppColors.cyan : Colors.white),
        onPressed: onTap,
      );

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(widget.game == null ? 'Close desktop?' : 'Quit ${widget.game!.name}?'),
        content: const Text('Unsaved progress in the game will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep playing')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quit')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context);
  }

  // ---------- overlays ----------
  Widget _statusOverlay(RuntimeService rt) {
    final starting = _textureId == null && _startError == null;
    final ended = rt.session == SessionState.ended;
    if (!starting && !ended && _startError == null) return const SizedBox.shrink();
    final title = _startError != null
        ? 'Could not start'
        : ended
            ? (widget.game == null ? 'Desktop closed' : '${widget.game!.name} closed')
            : (widget.game == null ? 'Starting Linux desktop' : 'Launching ${widget.game!.name}');
    return Container(
      color: AppColors.bg.withOpacity(ended ? 0.92 : 1),
      padding: const EdgeInsets.all(28),
      child: Row(children: [
        Expanded(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.asset('assets/logo.png', width: 64, height: 64)),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              _startError ??
                  (ended
                      ? 'Exit code ${rt.lastExitCode ?? '-'}. Check the log if it closed too early.'
                      : 'First launch of a game can take a minute while shaders and Wine warm up.'),
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            if (starting) const SizedBox(width: 220, child: LinearProgressIndicator(color: AppColors.cyan)),
            if (!starting)
              FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back), label: const Text('Back to library')),
          ]),
        ),
        const SizedBox(width: 20),
        Expanded(child: _logBox(rt)),
      ]),
    );
  }

  Widget _logBox(RuntimeService rt) => Container(
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.stroke)),
        padding: const EdgeInsets.all(10),
        child: ListView.builder(
          reverse: true,
          itemCount: rt.logs.length,
          itemBuilder: (_, i) => Text(rt.logs[rt.logs.length - 1 - i],
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final rt = context.watch<RuntimeService>();
    context.watch<EmulatorService>();
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(builder: (context, box) {
          final ar = _w / _h;
          var vw = box.maxWidth, vh = box.maxWidth / ar;
          if (vh > box.maxHeight) {
            vh = box.maxHeight;
            vw = vh * ar;
          }
          _view = Rect.fromLTWH((box.maxWidth - vw) / 2, (box.maxHeight - vh) / 2, vw, vh);
          return Stack(children: [
            if (_textureId != null) Positioned.fromRect(rect: _view, child: Texture(textureId: _textureId!, filterQuality: FilterQuality.medium)),
            // trackpad cursor hint
            if (_mode == 'trackpad' && _textureId != null)
              Positioned(
                left: _view.left + _cursor.dx / _w * _view.width - 3,
                top: _view.top + _cursor.dy / _h * _view.height - 3,
                child: IgnorePointer(
                  child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.cyan, shape: BoxShape.circle)),
                ),
              ),
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onDown,
                onPointerMove: _onMove,
                onPointerUp: _onUp,
                onPointerCancel: _onUp,
              ),
            ),
            if (_mode == 'gamepad') Positioned.fill(child: _gamepad()),
            // hidden IME field
            Positioned(
              left: -1000,
              top: 0,
              width: 10,
              height: 10,
              child: TextField(
                controller: _imeCtrl,
                focusNode: _imeFocus,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                onChanged: _onImeChanged,
                onSubmitted: (_) {
                  _tapKey('Return');
                  _imeFocus.requestFocus();
                },
              ),
            ),
            if (_showKeys) Positioned(left: 0, right: 0, bottom: MediaQuery.of(context).viewInsets.bottom, child: _keyBar()),
            _toolbar(),
            if (!_showToolbar)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _showToolbar = true),
                    child: Container(
                      width: 70,
                      height: 18,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.expand_more, size: 16),
                    ),
                  ),
                ),
              ),
            Positioned.fill(child: _statusOverlay(rt)),
          ]);
        }),
      ),
    );
  }
}
