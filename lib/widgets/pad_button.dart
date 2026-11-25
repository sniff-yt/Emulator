import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A press-and-hold button: onDown when the finger lands, onUp when it lifts.
class PadButton extends StatefulWidget {
  final String label;
  final String? sub;
  final Color color;
  final double size;
  final bool round;
  final bool haptics;
  final double opacity;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final bool toggled;

  const PadButton({
    super.key,
    required this.label,
    this.sub,
    required this.color,
    required this.onDown,
    required this.onUp,
    this.size = 62,
    this.round = true,
    this.haptics = true,
    this.opacity = 0.55,
    this.toggled = false,
  });

  @override
  State<PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<PadButton> {
  bool _down = false;

  void _press() {
    if (_down) return;
    setState(() => _down = true);
    if (widget.haptics) HapticFeedback.lightImpact();
    widget.onDown();
  }

  void _release() {
    if (!_down) return;
    setState(() => _down = false);
    widget.onUp();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final lit = _down || widget.toggled;
    return Opacity(
      opacity: lit ? 1 : widget.opacity,
      child: Listener(
        onPointerDown: (_) => _press(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          width: widget.round ? widget.size : widget.size * 1.5,
          height: widget.round ? widget.size : widget.size * 0.62,
          decoration: BoxDecoration(
            shape: widget.round ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.round ? null : BorderRadius.circular(12),
            color: lit ? c.withOpacity(0.55) : Colors.black.withOpacity(0.35),
            border: Border.all(color: c, width: 2),
            boxShadow: lit ? [BoxShadow(color: c.withOpacity(0.6), blurRadius: 14)] : null,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: widget.size * (widget.round ? 0.3 : 0.24))),
              if (widget.sub != null)
                Text(widget.sub!, style: TextStyle(color: Colors.white70, fontSize: widget.size * 0.15)),
            ],
          ),
        ),
      ),
    );
  }
}
