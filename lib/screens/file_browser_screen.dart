import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/platform.dart';

/// Pick a Windows program (.exe / .bat / .msi) from phone storage.
class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key});
  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> with WidgetsBindingObserver {
  static const root = '/storage/emulated/0';
  String _dir = root;
  List<FileSystemEntity> _items = [];
  bool _allowed = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final ok = await NativePlatform.hasStorage();
    setState(() => _allowed = ok);
    if (ok) _load(_dir);
  }

  void _load(String dir) {
    try {
      final list = Directory(dir).listSync(followLinks: false).where((e) {
        final n = e.path.split('/').last;
        if (n.startsWith('.')) return false;
        if (e is Directory) return true;
        final l = n.toLowerCase();
        return l.endsWith('.exe') || l.endsWith('.bat') || l.endsWith('.msi') || l.endsWith('.lnk');
      }).toList()
        ..sort((a, b) {
          if (a is Directory && b is! Directory) return -1;
          if (b is Directory && a is! Directory) return 1;
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });
      setState(() {
        _dir = dir;
        _items = list;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Cannot open this folder');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rel = _dir == root ? 'Phone storage' : _dir.replaceFirst('$root/', '');
    return PopScope(
      canPop: _dir == root,
      onPopInvoked: (didPop) {
        if (!didPop) _load(Directory(_dir).parent.path);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Choose the game .exe'),
            Text(rel, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w400)),
          ]),
        ),
        body: !_allowed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.folder_off, size: 56, color: AppColors.muted),
                    const SizedBox(height: 14),
                    const Text('Allow file access so games on your phone can be opened.', textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: NativePlatform.requestStorage, child: const Text('Allow access')),
                  ]),
                ),
              )
            : _error != null
                ? Center(child: Text(_error!))
                : ListView.builder(
                    itemCount: _items.length + (_dir == root ? 0 : 1),
                    itemBuilder: (_, i) {
                      if (_dir != root && i == 0) {
                        return ListTile(
                          leading: const Icon(Icons.arrow_upward, color: AppColors.muted),
                          title: const Text('..'),
                          onTap: () => _load(Directory(_dir).parent.path),
                        );
                      }
                      final e = _items[i - (_dir == root ? 0 : 1)];
                      final name = e.path.split('/').last;
                      final isDir = e is Directory;
                      return ListTile(
                        leading: Icon(isDir ? Icons.folder : Icons.sports_esports, color: isDir ? AppColors.amber : AppColors.cyan),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: isDir ? const Icon(Icons.chevron_right, color: AppColors.muted) : null,
                        onTap: () => isDir ? _load(e.path) : Navigator.pop(context, e.path),
                      );
                    },
                  ),
      ),
    );
  }
}
