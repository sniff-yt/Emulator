import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../services/emulator_service.dart';
import '../models/game_profile.dart';

class EmulatorScreen extends StatefulWidget {
  final GameProfile profile;
  const EmulatorScreen({super.key, required this.profile});

  @override
  State<EmulatorScreen> createState() => _EmulatorScreenState();
}

class _EmulatorScreenState extends State<EmulatorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmulatorService>().launch(widget.profile);
    });
  }

  @override
  void dispose() {
    context.read<EmulatorService>().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<EmulatorService>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.monitor, size: 96, color: Colors.white24),
                const SizedBox(height: 12),
                Text(widget.profile.name, style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 8),
                Text('${svc.fps.toStringAsFixed(0)} FPS', style: const TextStyle(color: Colors.greenAccent, fontSize: 20)),
                const SizedBox(height: 4),
                Text('RAM ${svc.ramMB}MB · ${svc.cpuCores} cores', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          // Left joystick
          Positioned(
            left: 24,
            bottom: 24,
            child: SizedBox(
              width: 140,
              height: 140,
              child: Joystick(
                listener: (details) {},
              ),
            ),
          ),
          // Action buttons
          Positioned(
            right: 24,
            bottom: 40,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _btn('A', Colors.redAccent),
                _btn('B', Colors.blueAccent),
                _btn('X', Colors.greenAccent),
                _btn('Y', Colors.amberAccent),
              ],
            ),
          ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.fullscreen, color: Colors.white),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, Color color) {
    return GestureDetector(
      onTapDown: (_) {},
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.25),
          border: Border.all(color: color, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
    );
  }
}