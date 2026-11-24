import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'core/theme.dart';
import 'services/emulator_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PcEmulatorApp());
}

class PcEmulatorApp extends StatelessWidget {
  const PcEmulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmulatorService(),
      child: MaterialApp(
        title: 'PC Emulator',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const HomeScreen(),
      ),
    );
  }
}