/// Download sources for the runtime. All arm64 (aarch64) builds.
class RuntimeConfig {
  /// Debian 13 (trixie) slim root filesystem, official debuerreotype build.
  static const rootfsUrl =
      'https://raw.githubusercontent.com/debuerreotype/docker-debian-artifacts/dist-arm64v8/trixie/slim/oci/blobs/rootfs.tar.gz';

  /// Wine 11.0 staging, x86_64 WoW64 build (runs 32 and 64-bit games, no i386 libs needed). Runs through box64.
  static const wineUrl =
      'https://github.com/Kron4ek/Wine-Builds/releases/download/11.0/wine-11.0-staging-amd64-wow64.tar.xz';

  /// DXVK: Direct3D 8/9/10/11 to Vulkan.
  static const dxvkUrl = 'https://github.com/doitsujin/dxvk/releases/download/v2.7.1/dxvk-2.7.1.tar.gz';

  /// Mesa with the Turnip (Adreno) Vulkan driver built for glibc containers on Android.
  static const mesaUrl =
      'https://github.com/lfdevs/mesa-for-android-container/releases/download/mesa-27.0.0-devel-20261025-r2/mesa-for-android-container_27.0.0-devel-20261025-r2_debian_trixie_arm64.tar.gz';

  static const setupVersion = 1;
  static const inputPort = 7788;
}

class Resolution {
  final int w, h;
  const Resolution(this.w, this.h);
  String get label => '${w}x$h';
  static const options = [
    Resolution(854, 480),
    Resolution(960, 540),
    Resolution(1280, 720),
    Resolution(1600, 900),
    Resolution(1920, 1080),
  ];
  static Resolution parse(String s) {
    final p = s.split('x');
    return Resolution(int.parse(p[0]), int.parse(p[1]));
  }
}
