class GameProfile {
  final String id;
  final String name;
  final String path;
  final String platform; // windows, dos, linux
  final int ramMB;
  final int cpuCores;
  final bool fullscreen;
  final DateTime addedAt;

  GameProfile({
    required this.id,
    required this.name,
    required this.path,
    this.platform = 'windows',
    this.ramMB = 2048,
    this.cpuCores = 2,
    this.fullscreen = true,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'platform': platform,
        'ramMB': ramMB,
        'cpuCores': cpuCores,
        'fullscreen': fullscreen,
        'addedAt': addedAt.toIso8601String(),
      };

  factory GameProfile.fromJson(Map<String, dynamic> j) => GameProfile(
        id: j['id'],
        name: j['name'],
        path: j['path'],
        platform: j['platform'] ?? 'windows',
        ramMB: j['ramMB'] ?? 2048,
        cpuCores: j['cpuCores'] ?? 2,
        fullscreen: j['fullscreen'] ?? true,
        addedAt: DateTime.tryParse(j['addedAt'] ?? '') ?? DateTime.now(),
      );
}