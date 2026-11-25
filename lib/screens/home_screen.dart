import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/game_profile.dart';
import '../services/emulator_service.dart';
import '../services/runtime_service.dart';
import 'display_screen.dart';
import 'file_browser_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rt = context.watch<RuntimeService>();
    final app = context.watch<EmulatorService>();
    final ready = rt.state == EngineState.ready;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _header(context, rt)),
          if (rt.updateBuild != null) SliverToBoxAdapter(child: _updateBanner(rt)),
          SliverToBoxAdapter(child: _engineCard(context, rt)),
          SliverToBoxAdapter(child: _quickActions(context, ready)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
              child: Row(children: [
                const Text('Your games', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${app.games.length}', style: const TextStyle(color: AppColors.muted)),
              ]),
            ),
          ),
          if (app.games.isEmpty)
            SliverToBoxAdapter(child: _emptyLibrary(context, ready))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _GameCard(game: app.games[i], ready: ready),
                  childCount: app.games.length,
                ),
              ),
            ),
        ]),
      ),
      floatingActionButton: ready
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.violet,
              onPressed: () => addGame(context),
              icon: const Icon(Icons.add),
              label: const Text('Add game'),
            )
          : null,
    );
  }

  Widget _header(BuildContext context, RuntimeService rt) {
    final soc = (rt.device['soc'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/logo.png', width: 52, height: 52)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShaderMask(
              shaderCallback: (r) => AppColors.gradient.createShader(r),
              child: const Text('PC Emulator', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            Text(
              soc.isEmpty ? 'Windows games on Android' : '${rt.device['model']} · $soc',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ]),
    );
  }

  Widget _updateBanner(RuntimeService rt) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.green.withOpacity(0.5)),
          ),
          child: Row(children: [
            const Icon(Icons.system_update, color: AppColors.green),
            const SizedBox(width: 12),
            Expanded(child: Text('New app version ready (build ${rt.updateBuild})', style: const TextStyle(fontWeight: FontWeight.w600))),
            TextButton(onPressed: rt.openUpdate, child: const Text('Update')),
          ]),
        ),
      );

  Widget _engineCard(BuildContext context, RuntimeService rt) {
    final ready = rt.state == EngineState.ready;
    final installing = rt.state == EngineState.installing;
    final gpu = rt.gpuCapable;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: ready
              ? const LinearGradient(colors: [Color(0xFF1B1F3B), Color(0xFF14283A)])
              : const LinearGradient(colors: [Color(0xFF2A1F5C), Color(0xFF123447)]),
          border: Border.all(color: AppColors.stroke),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
            child: Icon(ready ? Icons.memory : Icons.download_rounded, color: ready ? AppColors.green : AppColors.cyan),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                ready ? 'Engine ready' : (installing ? 'Setting up… ${(rt.progress * 100).round()}%' : 'Set up the engine'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                ready
                    ? 'Debian · box64 · Wine 11 · ${gpu ? 'Turnip GPU + DXVK' : 'software rendering'}'
                    : 'Linux, box64, Wine and the Adreno GPU driver. About 1.5 GB, once.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              if (installing) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(value: rt.progress.clamp(0.02, 1.0), color: AppColors.cyan, backgroundColor: Colors.white10),
              ],
            ]),
          ),
          if (!ready) ...[
            const SizedBox(width: 10),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
              onPressed: () {
                if (!installing) rt.install();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen()));
              },
              child: Text(installing ? 'View' : (rt.state == EngineState.failed ? 'Resume' : 'Install')),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _quickActions(BuildContext context, bool ready) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.desktop_windows_rounded,
            title: 'Linux desktop',
            subtitle: 'XFCE with Wine',
            colors: const [AppColors.violet, Color(0xFF5B3FD6)],
            enabled: ready,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DisplayScreen())),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.add_box_rounded,
            title: 'Add a game',
            subtitle: 'Pick its .exe',
            colors: const [Color(0xFF0E9FB8), AppColors.cyan],
            enabled: ready,
            onTap: () => addGame(context),
          ),
        ),
      ]),
    );
  }

  Widget _emptyLibrary(BuildContext context, bool ready) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Icon(Icons.videogame_asset_outlined, size: 48, color: AppColors.muted),
              const SizedBox(height: 10),
              const Text('No games yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                ready
                    ? 'Copy a PC game folder to your phone, then add its .exe here.'
                    : 'Set up the engine first, then add games from your phone storage.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ]),
          ),
        ),
      );

  static Future<void> addGame(BuildContext context) async {
    final path = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const FileBrowserScreen()));
    if (path == null || !context.mounted) return;
    final app = context.read<EmulatorService>();
    final file = path.split('/').last;
    final folder = path.split('/').reversed.skip(1).firstOrNull ?? file;
    var name = file.replaceAll(RegExp(r'\.(exe|bat|msi|lnk)$', caseSensitive: false), '');
    if (const ['game', 'launcher', 'start', 'setup', 'bin', 'win64', 'x64'].contains(name.toLowerCase())) name = folder;
    final g = GameProfile(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, path: path, renderer: app.renderer);
    app.addGame(g);
    if (context.mounted) showGameSheet(context, g);
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final List<Color> colors;
  final bool enabled;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.colors, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.4,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 104,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: Colors.white, size: 28),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ]),
          ),
        ),
      );
}

class _GameCard extends StatelessWidget {
  final GameProfile game;
  final bool ready;
  const _GameCard({required this.game, required this.ready});

  static const _palettes = [
    [Color(0xFF7C5CFF), Color(0xFF22D3EE)],
    [Color(0xFFF472B6), Color(0xFF7C3AED)],
    [Color(0xFF34D399), Color(0xFF0EA5E9)],
    [Color(0xFFFBBF24), Color(0xFFEF4444)],
    [Color(0xFF60A5FA), Color(0xFF6366F1)],
  ];

  @override
  Widget build(BuildContext context) {
    final p = _palettes[game.name.hashCode.abs() % _palettes.length];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: ready ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => DisplayScreen(game: game))) : null,
        onLongPress: () => showGameSheet(context, game),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(colors: p, begin: Alignment.topLeft, end: Alignment.bottomRight)),
              child: Stack(children: [
                Center(
                  child: Text(
                    game.name.isEmpty ? '?' : game.name.characters.first.toUpperCase(),
                    style: TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.92)),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(20)),
                    child: Text(game.renderer == 'gpu' ? 'GPU' : 'CPU',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                ),
                const Positioned(left: 10, bottom: 10, child: Icon(Icons.play_circle_fill, size: 30, color: Colors.white)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(children: [
              Expanded(
                child: Text(game.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              InkWell(
                onTap: () => showGameSheet(context, game),
                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.more_vert, size: 18, color: AppColors.muted)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Edit a game: name, renderer, resolution, launch arguments, delete.
Future<void> showGameSheet(BuildContext context, GameProfile game) {
  final app = context.read<EmulatorService>();
  final nameCtrl = TextEditingController(text: game.name);
  final argsCtrl = TextEditingController(text: game.args);
  var renderer = game.renderer;
  String? res = game.resolution;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Text(game.path, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 16),
            const Text('Graphics', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'gpu', label: Text('GPU (Turnip + DXVK)'), icon: Icon(Icons.bolt)),
                ButtonSegment(value: 'software', label: Text('Software'), icon: Icon(Icons.memory)),
              ],
              selected: {renderer},
              onSelectionChanged: (s) => set(() => renderer = s.first),
            ),
            const SizedBox(height: 16),
            const Text('Resolution', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(label: Text('Default (${app.resolution})'), selected: res == null, onSelected: (_) => set(() => res = null)),
              for (final r in Resolution.options)
                ChoiceChip(label: Text(r.label), selected: res == r.label, onSelected: (_) => set(() => res = r.label)),
            ]),
            const SizedBox(height: 16),
            TextField(controller: argsCtrl, decoration: const InputDecoration(labelText: 'Launch options (optional)', hintText: '-windowed -dx9', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            Row(children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.red),
                onPressed: () {
                  app.removeGame(game.id);
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  app.updateGame(game.copyWith(
                    name: nameCtrl.text.trim().isEmpty ? game.name : nameCtrl.text.trim(),
                    renderer: renderer,
                    resolution: res,
                    clearResolution: res == null,
                    args: argsCtrl.text.trim(),
                  ));
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );
}
