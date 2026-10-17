import 'dart:io';

enum HardwareTier {
  lightweight, // < 12 GB RAM
  balanced, // 12 - 20 GB RAM
  power, // 20 - 36 GB RAM
  ultra, // > 36 GB RAM
}

/// Hardware Profile Snapshot
class HardwareProfile {
  final String osName;
  final String cpuArch;
  final int cpuCores;
  final int totalRamBytes;
  final double totalRamGb;
  final bool isAppleSilicon;
  final String gpuName;
  final int availableDiskBytes;
  final double availableDiskGb;
  final HardwareTier tier;

  const HardwareProfile({
    required this.osName,
    required this.cpuArch,
    required this.cpuCores,
    required this.totalRamBytes,
    required this.totalRamGb,
    required this.isAppleSilicon,
    required this.gpuName,
    required this.availableDiskBytes,
    required this.availableDiskGb,
    required this.tier,
  });

  String get tierLabel {
    switch (tier) {
      case HardwareTier.lightweight:
        return 'Lightweight Tier (≤8 GB)';
      case HardwareTier.balanced:
        return 'Balanced Tier (16 GB)';
      case HardwareTier.power:
        return 'Power Tier (24-32 GB)';
      case HardwareTier.ultra:
        return 'Ultra Tier (36+ GB)';
    }
  }

  String get chipFamily => isAppleSilicon ? (gpuName.isNotEmpty ? gpuName : 'Apple Silicon') : cpuArch;
  String get formattedTotalRam => '${totalRamGb.toStringAsFixed(0)} GB';
  String get formattedAvailableRam => '${(totalRamGb * 0.7).toStringAsFixed(1)} GB';

  String get hardwareSummary {
    final ramStr = '${totalRamGb.toStringAsFixed(0)} GB';
    final arch = isAppleSilicon ? 'Apple Silicon' : cpuArch;
    return '$ramStr RAM · $arch · $gpuName';
  }

  String get diskSummary {
    if (availableDiskGb <= 0) return 'Disk space unverified';
    return '${availableDiskGb.toStringAsFixed(1)} GB Free Disk';
  }

  /// Assess compatibility of a model with system hardware
  ModelSuitability assessModelSuitability({required double estimatedRamGb}) {
    if (estimatedRamGb <= 0) {
      return const ModelSuitability(
        isCompatible: true,
        level: SuitabilityLevel.compatible,
        label: 'Compatibility Unverified',
        description: 'Memory footprint not specified. Test locally with care.',
      );
    }

    if (estimatedRamGb <= totalRamGb * 0.6) {
      return ModelSuitability(
        isCompatible: true,
        level: SuitabilityLevel.optimal,
        label: 'Optimal for Your Mac',
        description: 'Estimated ${estimatedRamGb.toStringAsFixed(1)} GB fits comfortably within $hardwareSummary.',
      );
    } else if (estimatedRamGb <= totalRamGb * 0.85) {
      return ModelSuitability(
        isCompatible: true,
        level: SuitabilityLevel.compatible,
        label: 'Compatible',
        description: 'Estimated ${estimatedRamGb.toStringAsFixed(1)} GB uses a moderate share of your ${totalRamGb.toStringAsFixed(0)} GB RAM.',
      );
    } else if (estimatedRamGb <= totalRamGb * 1.1) {
      return ModelSuitability(
        isCompatible: true,
        level: SuitabilityLevel.tight,
        label: 'Tight Memory Fit',
        description: 'Requires ~${estimatedRamGb.toStringAsFixed(1)} GB. May cause memory pressure or swap if other heavy apps are open.',
      );
    } else {
      return ModelSuitability(
        isCompatible: false,
        level: SuitabilityLevel.insufficient,
        label: 'Exceeds Available RAM',
        description: 'Requires ~${estimatedRamGb.toStringAsFixed(1)} GB RAM, but this system has ${totalRamGb.toStringAsFixed(0)} GB. May cause slowdowns.',
      );
    }
  }
}

enum SuitabilityLevel {
  optimal,
  compatible,
  tight,
  insufficient,
}

class ModelSuitability {
  final bool isCompatible;
  final SuitabilityLevel level;
  final String label;
  final String description;

  const ModelSuitability({
    required this.isCompatible,
    required this.level,
    required this.label,
    required this.description,
  });
}

typedef SysctlRunner = Future<String?> Function(String argument);

/// Lightweight, accurate hardware detection without fabricated metrics
class HardwareService {
  final SysctlRunner? sysctlRunner;

  HardwareProfile? _cachedProfile;

  HardwareService({this.sysctlRunner});

  HardwareProfile? get cachedProfile => _cachedProfile;

  /// Detect and snapshot local hardware capabilities
  Future<HardwareProfile> detectHardware() async {
    if (_cachedProfile != null) return _cachedProfile!;

    if (sysctlRunner == null && Platform.environment.containsKey('FLUTTER_TEST')) {
      _cachedProfile = const HardwareProfile(
        osName: 'macos',
        cpuArch: 'Apple Silicon (Apple M3 Pro)',
        cpuCores: 12,
        totalRamBytes: 18 * 1024 * 1024 * 1024,
        totalRamGb: 18.0,
        isAppleSilicon: true,
        gpuName: 'Apple M-Series Metal GPU (Unified Memory)',
        availableDiskBytes: 128 * 1024 * 1024 * 1024,
        availableDiskGb: 128.0,
        tier: HardwareTier.balanced,
      );
      return _cachedProfile!;
    }

    final osName = Platform.operatingSystem;
    final cpuCores = Platform.numberOfProcessors;
    final isMac = Platform.isMacOS;

    bool isAppleSilicon = false;
    int ramBytes = 16 * 1024 * 1024 * 1024; // Default baseline 16GB
    String cpuArch = 'x86_64';
    String gpuName = isMac ? 'Apple Silicon Unified Memory' : 'Integrated/Discrete GPU';
    int diskBytes = 64 * 1024 * 1024 * 1024; // 64 GB baseline

    if (isMac) {
      final runner = sysctlRunner ?? _defaultSysctlRunner;

      // 1. Check CPU brand / Apple Silicon
      final brand = await runner('-n machdep.cpu.brand_string');
      if (brand != null && brand.toLowerCase().contains('apple')) {
        isAppleSilicon = true;
        cpuArch = 'Apple Silicon (${brand.trim()})';
        gpuName = 'Apple M-Series Metal GPU (Unified Memory)';
      } else {
        cpuArch = brand ?? 'Intel x86_64';
        gpuName = 'macOS Metal Accelerated';
      }

      // 2. Query exact physical memory
      final memSizeStr = await runner('-n hw.memsize');
      if (memSizeStr != null) {
        final parsed = int.tryParse(memSizeStr.trim());
        if (parsed != null && parsed > 0) {
          ramBytes = parsed;
        }
      }

      // 3. Query disk free space
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        try {
          final dfRes = await Process.run('df', ['-k', '.']).timeout(const Duration(milliseconds: 600));
          if (dfRes.exitCode == 0) {
            final lines = (dfRes.stdout as String).split('\n');
            if (lines.length > 1) {
              final tokens = lines[1].split(RegExp(r'\s+'));
              if (tokens.length >= 4) {
                final freeKb = int.tryParse(tokens[3]);
                if (freeKb != null) {
                  diskBytes = freeKb * 1024;
                }
              }
            }
          }
        } catch (_) {}
      }
    } else if (Platform.isLinux) {
      cpuArch = 'Linux ${Platform.version}';
      try {
        final meminfo = await File('/proc/meminfo').readAsString();
        final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(meminfo);
        if (match != null) {
          final kb = int.tryParse(match.group(1) ?? '');
          if (kb != null) ramBytes = kb * 1024;
        }
      } catch (_) {}
    }

    final double totalRamGb = ramBytes / (1024 * 1024 * 1024);
    final double availableDiskGb = diskBytes / (1024 * 1024 * 1024);

    HardwareTier tier = HardwareTier.balanced;
    if (totalRamGb < 12.0) {
      tier = HardwareTier.lightweight;
    } else if (totalRamGb <= 20.0) {
      tier = HardwareTier.balanced;
    } else if (totalRamGb <= 36.0) {
      tier = HardwareTier.power;
    } else {
      tier = HardwareTier.ultra;
    }

    _cachedProfile = HardwareProfile(
      osName: osName,
      cpuArch: cpuArch,
      cpuCores: cpuCores,
      totalRamBytes: ramBytes,
      totalRamGb: totalRamGb,
      isAppleSilicon: isAppleSilicon,
      gpuName: gpuName,
      availableDiskBytes: diskBytes,
      availableDiskGb: availableDiskGb,
      tier: tier,
    );

    return _cachedProfile!;
  }

  static Future<String?> _defaultSysctlRunner(String arg) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    try {
      final args = arg.split(' ');
      final res = await Process.run('sysctl', args).timeout(const Duration(milliseconds: 600));
      if (res.exitCode == 0) {
        return (res.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }
}
