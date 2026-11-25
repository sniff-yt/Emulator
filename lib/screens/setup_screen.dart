import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/runtime_service.dart';

/// Installs the engine: Debian, desktop, box64, Turnip, Wine, DXVK.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _showLog = false;
  static const _steps = [
    'Linux image',
    'Package lists',
    'Desktop and X server',
    'box64 and graphics',
    'Turnip GPU driver',
    'Wine',
    'DXVK',
    'Windows environment',
  ];

  @override
  Widget build(BuildContext context) {
    final rt = context.watch<RuntimeService>();
    final installing = rt.state == EngineState.installing;
    final done = rt.state == EngineState.ready;
    final failed = rt.state == EngineState.failed;
    // step 0 = rootfs download, 1..7 = setup.sh steps
    final current = installing ? (rt.step == 0 ? 0 : rt.step) : (done ? _steps.length : -1);
    return Scaffold(
      appBar: AppBar(title: const Text('Engine setup')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(done ? Icons.check_circle : (failed ? Icons.error : Icons.downloading),
                        color: done ? AppColors.green : (failed ? AppColors.red : AppColors.cyan)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        done ? 'Engine ready' : (failed ? 'Setup stopped' : (installing ? rt.status : 'One-time download, about 1.5 GB')),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (installing) Text('${(rt.progress * 100).round()}%', style: const TextStyle(color: AppColors.muted)),
                  ]),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: done ? 1 : (installing ? rt.progress.clamp(0.02, 1.0) : 0),
                      minHeight: 8,
                      backgroundColor: AppColors.surface2,
                      color: failed ? AppColors.red : AppColors.cyan,
                    ),
                  ),
                  if (failed && rt.error != null) ...[
                    const SizedBox(height: 12),
                    Text(rt.error!, style: const TextStyle(color: AppColors.red)),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Use Wi-Fi and keep the app open. If it stops, tap Resume and it continues where it left off.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _steps.length; i++) _stepTile(i, _steps[i], current, failed),
            const SizedBox(height: 16),
            if (!installing && !done)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppColors.violet),
                onPressed: rt.install,
                icon: Icon(failed ? Icons.refresh : Icons.download),
                label: Text(failed ? 'Resume setup' : 'Start setup'),
              ),
            if (done)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppColors.green),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.sports_esports),
                label: const Text('Start playing'),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _showLog = !_showLog),
              icon: Icon(_showLog ? Icons.expand_less : Icons.terminal),
              label: Text(_showLog ? 'Hide log' : 'Show log'),
            ),
            if (_showLog)
              Container(
                height: 280,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.stroke)),
                padding: const EdgeInsets.all(10),
                child: ListView.builder(
                  reverse: true,
                  itemCount: rt.logs.length,
                  itemBuilder: (_, i) => Text(rt.logs[rt.logs.length - 1 - i],
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepTile(int i, String title, int current, bool failed) {
    final state = i < current ? 2 : (i == current ? 1 : 0);
    final color = state == 2 ? AppColors.green : (state == 1 ? (failed ? AppColors.red : AppColors.cyan) : AppColors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15), border: Border.all(color: color)),
          alignment: Alignment.center,
          child: state == 2
              ? Icon(Icons.check, size: 16, color: color)
              : state == 1 && !failed
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                  : Text('${i + 1}', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 14),
        Text(title, style: TextStyle(color: state == 0 ? AppColors.muted : AppColors.text, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
