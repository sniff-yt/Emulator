import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../services/emulator_service.dart';
import '../services/runtime_service.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<EmulatorService>();
    final rt = context.watch<RuntimeService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _section('Display'),
          _card([
            ListTile(
              title: const Text('Default resolution'),
              subtitle: const Text('Lower is faster'),
              trailing: DropdownButton<String>(
                value: s.resolution,
                underline: const SizedBox(),
                items: [for (final r in Resolution.options) DropdownMenuItem(value: r.label, child: Text(r.label))],
                onChanged: (v) => s.update((x) => x.resolution = v!),
              ),
            ),
            ListTile(
              title: const Text('Frame cap'),
              trailing: DropdownButton<int>(
                value: s.fpsCap,
                underline: const SizedBox(),
                items: const [30, 45, 60].map((v) => DropdownMenuItem(value: v, child: Text('$v fps'))).toList(),
                onChanged: (v) => s.update((x) => x.fpsCap = v!),
              ),
            ),
            ListTile(
              title: const Text('Default graphics'),
              subtitle: Text(rt.gpuCapable ? 'Adreno GPU detected' : 'No Adreno GPU found, use Software'),
              trailing: DropdownButton<String>(
                value: s.renderer,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'gpu', child: Text('GPU')),
                  DropdownMenuItem(value: 'software', child: Text('Software')),
                ],
                onChanged: (v) => s.update((x) => x.renderer = v!),
              ),
            ),
          ]),
          _section('Controls'),
          _card([
            ListTile(
              title: const Text('Start in'),
              trailing: DropdownButton<String>(
                value: s.touchMode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'trackpad', child: Text('Mouse (trackpad)')),
                  DropdownMenuItem(value: 'direct', child: Text('Touch (direct)')),
                  DropdownMenuItem(value: 'gamepad', child: Text('Gamepad')),
                ],
                onChanged: (v) => s.update((x) => x.touchMode = v!),
              ),
            ),
            ListTile(
              title: const Text('Stick moves with'),
              trailing: DropdownButton<String>(
                value: s.stickKeys,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'wasd', child: Text('W A S D')),
                  DropdownMenuItem(value: 'arrows', child: Text('Arrow keys')),
                ],
                onChanged: (v) => s.update((x) => x.stickKeys = v!),
              ),
            ),
            _slider('Mouse speed', s.mouseSensitivity, 0.5, 3, (v) => s.update((x) => x.mouseSensitivity = v)),
            _slider('Camera look speed', s.lookSensitivity, 0.5, 4, (v) => s.update((x) => x.lookSensitivity = v)),
            _slider('Button size', s.buttonScale, 0.7, 1.4, (v) => s.update((x) => x.buttonScale = v)),
            _slider('Button opacity', s.controlsOpacity, 0.2, 1, (v) => s.update((x) => x.controlsOpacity = v)),
            SwitchListTile(title: const Text('Vibration on press'), value: s.haptics, onChanged: (v) => s.update((x) => x.haptics = v)),
          ]),
          _section('How controls work'),
          _card(const [
            ListTile(
              dense: true,
              title: Text('Mouse mode'),
              subtitle: Text('Drag to move the cursor, tap to click, two-finger tap to right-click, hold then drag to drag, two fingers up or down to scroll.'),
            ),
            ListTile(dense: true, title: Text('Touch mode'), subtitle: Text('Tap exactly where you want to click.')),
            ListTile(
              dense: true,
              title: Text('Gamepad mode'),
              subtitle: Text('Left stick walks, drag the right side to look around. RT fires, LT aims, A jumps, B crouches, X reloads, Y uses.'),
            ),
          ]),
          _section('Engine'),
          _card([
            ListTile(
              leading: const Icon(Icons.build_circle_outlined),
              title: const Text('Engine setup'),
              subtitle: Text(rt.state == EngineState.ready ? 'Installed' : 'Not installed'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reset Windows environment'),
              subtitle: const Text('Fixes games that broke Wine. Keeps your games.'),
              onTap: rt.state != EngineState.ready
                  ? null
                  : () async {
                      final m = ScaffoldMessenger.of(context);
                      m.showSnackBar(const SnackBar(content: Text('Resetting Windows environment…')));
                      final code = await rt.resetWindows();
                      m.showSnackBar(SnackBar(content: Text(code == 0 ? 'Done' : 'Reset failed (code $code)')));
                    },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: AppColors.red),
              title: const Text('Remove engine'),
              subtitle: const Text('Frees about 2 GB'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Remove the engine?'),
                    content: const Text('Linux, Wine and saved Windows settings are deleted. Game files on your phone are not touched.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
                    ],
                  ),
                );
                if (ok == true) await rt.uninstall();
              },
            ),
          ]),
          const SizedBox(height: 16),
          const Center(
            child: Text('Debian 13 · box64 · Wine 11 · DXVK 2.7 · Mesa Turnip',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: AppColors.cyan)),
      );

  Widget _card(List<Widget> children) => Card(child: Column(children: children));

  Widget _slider(String label, double value, double min, double max, ValueChanged<double> onChanged) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(label), const Spacer(), Text(value.toStringAsFixed(1), style: const TextStyle(color: AppColors.muted))]),
          Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
        ]),
      );
}
