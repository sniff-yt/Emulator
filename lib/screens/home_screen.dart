import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'game_library_screen.dart';
import 'emulator_screen.dart';
import 'settings_screen.dart';
import '../services/emulator_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('PC Emulator', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Run PC games on Android', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _tile(context, Icons.library_books, 'Game Library', () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const GameLibraryScreen()))),
                    _tile(context, Icons.play_circle_fill, 'Launch', () {
                      final s = context.read<EmulatorService>();
                      if (s.games.isNotEmpty) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => EmulatorScreen(profile: s.games.first)));
                      }
                    }),
                    _tile(context, Icons.settings, 'Settings', () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                    _tile(context, Icons.info_outline, 'About', () => _about(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext ctx, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16161F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF6C63FF)),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _about(BuildContext ctx) {
    showAboutDialog(
      context: ctx,
      applicationName: 'PC Emulator',
      applicationVersion: '1.0.0',
      applicationLegalese: 'Emulation core: box86/box64 + Wine translation layer.\nResponsive on-screen controls.',
    );
  }
}