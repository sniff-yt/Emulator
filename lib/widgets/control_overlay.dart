import 'package:flutter/material.dart';

class ControlOverlay extends StatelessWidget {
  const ControlOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Stack(
        children: const [
          // Overlay hints for keyboard/mouse mapping
        ],
      ),
    );
  }
}