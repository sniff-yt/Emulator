class GameProfile {
  final String id;
  final String name;

  /// Path as seen on the phone, e.g. /storage/emulated/0/Games/foo/foo.exe
  final String path;
  final String renderer; // gpu | software
  final String? resolution; // e.g. 1280x720, null = app default
  final String args;
  final DateTime addedAt;
  final DateTime? lastPlayed;

  GameProfile({
    required this.id,
    required this.name,
    required this.path,
    this.renderer = 'gpu',
    this.resolution,
    this.args = '',
    DateTime? addedAt,
    this.lastPlayed,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Path inside the Linux container (/storage/emulated/0 is bound to /sdcard).
  String get containerPath => path.startsWith('/storage/emulated/0')
      ? path.replaceFirst('/storage/emulated/0', '/sdcard')
      : path.startsWith('/sdcard')
          ? path
          : path;

  GameProfile copyWith({String? name, String? renderer, String? resolution, bool clearResolution = false, String? args, DateTime? lastPlayed}) =>
      GameProfile(
        id: id,
        name: name ?? this.name,
        path: path,
        renderer: renderer ?? this.renderer,
        resolution: clearResolution ? null : (resolution ?? this.resolution),
        args: args ?? this.args,
        addedAt: addedAt,
        lastPlayed: lastPlayed ?? this.lastPlayed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'renderer': renderer,
        'resolution': resolution,
        'args': args,
        'addedAt': addedAt.toIso8601String(),
        'lastPlayed': lastPlayed?.toIso8601String(),
      };

  factory GameProfile.fromJson(Map<String, dynamic> j) => GameProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        path: j['path'] as String,
        renderer: (j['renderer'] as String?) ?? 'gpu',
        resolution: j['resolution'] as String?,
        args: (j['args'] as String?) ?? '',
        addedAt: DateTime.tryParse((j['addedAt'] as String?) ?? '') ?? DateTime.now(),
        lastPlayed: DateTime.tryParse((j['lastPlayed'] as String?) ?? ''),
      );
}
