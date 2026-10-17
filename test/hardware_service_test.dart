import 'package:flutter_test/flutter_test.dart';
import 'package:ollivo/services/hardware_service.dart';

void main() {
  group('HardwareService & System Telemetry Tests', () {
    test('Correctly identifies 8GB Apple Silicon and categorizes as lightweight tier', () async {
      final service = HardwareService(
        sysctlRunner: (arg) async {
          if (arg.contains('brand_string')) return 'Apple M1';
          if (arg.contains('hw.memsize')) return '8589934592'; // 8 GB
          return null;
        },
      );

      final profile = await service.detectHardware();
      expect(profile.isAppleSilicon, isTrue);
      expect(profile.totalRamGb, closeTo(8.0, 0.1));
      expect(profile.tier, HardwareTier.lightweight);
      expect(profile.tierLabel, contains('Lightweight Tier'));

      // 1.5GB model is optimal
      final lightSuitability = profile.assessModelSuitability(estimatedRamGb: 1.5);
      expect(lightSuitability.level, SuitabilityLevel.optimal);
      expect(lightSuitability.isCompatible, isTrue);

      // 14GB model exceeds 8GB RAM
      final heavySuitability = profile.assessModelSuitability(estimatedRamGb: 14.0);
      expect(heavySuitability.level, SuitabilityLevel.insufficient);
      expect(heavySuitability.isCompatible, isFalse);
    });

    test('Correctly identifies 16GB Apple Silicon and categorizes as balanced tier', () async {
      final service = HardwareService(
        sysctlRunner: (arg) async {
          if (arg.contains('brand_string')) return 'Apple M3 Pro';
          if (arg.contains('hw.memsize')) return '17179869184'; // 16 GB
          return null;
        },
      );

      final profile = await service.detectHardware();
      expect(profile.isAppleSilicon, isTrue);
      expect(profile.totalRamGb, closeTo(16.0, 0.1));
      expect(profile.tier, HardwareTier.balanced);

      // 4.5GB model (e.g. 7B) fits comfortably
      final midSuitability = profile.assessModelSuitability(estimatedRamGb: 4.5);
      expect(midSuitability.level, SuitabilityLevel.optimal);
    });

    test('Correctly identifies 36GB Apple Silicon as power tier', () async {
      final service = HardwareService(
        sysctlRunner: (arg) async {
          if (arg.contains('brand_string')) return 'Apple M3 Max';
          if (arg.contains('hw.memsize')) return '38654705664'; // 36 GB
          return null;
        },
      );

      final profile = await service.detectHardware();
      expect(profile.totalRamGb, closeTo(36.0, 0.1));
      expect(profile.tier, HardwareTier.power);

      // 18GB model is compatible
      final powerSuitability = profile.assessModelSuitability(estimatedRamGb: 18.0);
      expect(powerSuitability.isCompatible, isTrue);
    });
  });
}
