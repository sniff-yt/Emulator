import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Analog stick. Reports a vector in [-1,1] (y down positive) on every change.
class Joystick extends StatefulWidget {
  final double size;
  final double opacity;
  final ValueChanged<Offset> onChanged;
  final String label;
  const Joystick({super.key, required this.onChanged, this.size = 150, this.opacity = 0.55, this.label = ''});

  @override
  State<Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<Joystick> {
  Offset _knob = Offset.zero;
  bool _active = false;

  void _update(Offset local) {
    final r = widget.size / 2;
    var v = local - Offset(r, r);
    final maxR = r * 0.62;
    if (v.distance > maxR) v = v / v.distance * maxR;
    setState(() {
      _knob = v;
      _active = true;
    });
    widget.onChanged(Offset(v.dx / maxR, v.dy / maxR));
  }

  void _end() {
    setState(() {
      _knob = Offset.zero;
      _active = false;
    });
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Opacity(
      opacity: _active ? min(1.0, widget.opacity + 0.25) : widget.opacity,
      child: Listener(
        onPointerDown: (e) => _update(e.localPosition),
        onPointerMove: (e) => _update(e.localPosition),
        onPointerUp: (_) => _end(),
        onPointerCancel: (_) => _end(),
        child: SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.03)]),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
              ),
              if (widget.label.isNotEmpty)
                Positioned(
                  top: 8,
                  child: Text(widget.label, style: const TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1.2)),
                ),
              Transform.translate(
                offset: _knob,
                child: Container(
                  width: s * 0.42,
                  height: s * 0.42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.gradient,
                    boxShadow: [BoxShadow(color: AppColors.violet.withOpacity(0.5), blurRadius: 16)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
