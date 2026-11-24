import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/emulator_service.dart';
import '../models/game_profile.dart';
import 'emulator_screen.dart';

class GameLibraryScreen extends StatelessWidget {
  const GameLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<EmulatorService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Game Library')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C63FF),
        onPressed: () async {
          final r = await FilePicker.platform.pickFiles(type: FileType.any);
          if (r != null && r.files.single.path != null) {
            svc.addGame(GameProfile(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: r.files.single.name,
              path: r.files.single.path!,
            ));
          }
        },
        child: const Icon(Icons.add),
      ),
      body: svc.games.isEmpty
          ? const Center(child: Text('No games yet. Tap + to add.', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: svc.games.length,
              itemBuilder: (ctx, i) {
                final g = svc.games[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.videogame_asset, color: Color(0xFF6C63FF)),
                    title: Text(g.name),
                    subtitle: Text('${g.platform.toUpperCase()} · ${g.ramMB}MB · ${g.cpuCores} cores'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => svc.removeGame(g.id),
                    ),
                    onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => EmulatorScreen(profile: g))),
                  ),
                );
              },
            ),
    );
  }
}