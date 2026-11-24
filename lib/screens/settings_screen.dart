import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/emulator_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<EmulatorService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Performance'),
          _slider('RAM (MB)', svc.ramMB.toDouble(), 512, 8192, (v) => svc.setRam(v.round())),
          _slider('CPU Cores', svc.cpuCores.toDouble(), 1, 8, (v) => svc.setCores(v.round())),
          const SizedBox(height: 16),
          _section('Controls'),
          SwitchListTile(
            title: const Text('Haptic feedback'),
            value: true,
            onChanged: (_) {},
            activeColor: const Color(0xFF6C63FF),
          ),
          SwitchListTile(
            title: const Text('On-screen joystick'),
            value: true,
            onChanged: (_) {},
            activeColor: const Color(0xFF6C63FF),
          ),
          const SizedBox(height: 16),
          _section('Emulation'),
          ListTile(
            title: const Text('Translation layer'),
            subtitle: const Text('Box86/Box64 + Wine (x86→ARM)'),
            trailing: const Icon(Icons.chevron_right),
          ),
          ListTile(
            title: const Text('Graphics backend'),
            subtitle: const Text('Vulkan (fallback: OpenGL ES)'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 8),
        child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
      );

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value.round().toString(), style: const TextStyle(color: Colors.white54))],
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged, activeColor: const Color(0xFF6C63FF)),
      ],
    );
  }
}