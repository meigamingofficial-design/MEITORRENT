import 'package:flutter_test/flutter_test.dart';
import 'package:meitorrent/core/services/oem_battery_guard.dart';

void main() {
  group('OemBatteryGuard OEM Mapping Tests', () {
    final guard = OemBatteryGuard.instance;

    test('should support and identify aggressive OEMs', () {
      final knownOems = [
        'xiaomi',
        'redmi',
        'poco',
        'oppo',
        'realme',
        'vivo',
        'huawei',
        'honor',
        'samsung',
        'oneplus',
      ];

      for (final oem in knownOems) {
        expect(
          guard.isSupportedOem(oem),
          isTrue,
          reason: 'Expected $oem to be supported',
        );
      }
    });

    test('should normalize manufacturer input (case-insensitivity)', () {
      expect(guard.isSupportedOem('Xiaomi'), isTrue);
      expect(guard.isSupportedOem('SAMSUNG'), isTrue);
      expect(guard.isSupportedOem('OnePlus'), isTrue);
    });

    test('should reject non-restrictive or unknown manufacturers', () {
      final safeOems = [
        'google',
        'pixel',
        'motorola',
        'htc',
        'sony',
        'essential',
      ];
      for (final oem in safeOems) {
        expect(
          guard.isSupportedOem(oem),
          isFalse,
          reason: 'Expected $oem to not be restrictive',
        );
      }
    });

    test('should resolve the correct custom OS/OEM brand name', () {
      expect(guard.getOemName('xiaomi'), equals('MIUI'));
      expect(guard.getOemName('redmi'), equals('MIUI'));
      expect(guard.getOemName('poco'), equals('MIUI'));
      expect(guard.getOemName('samsung'), equals('OneUI'));
      expect(guard.getOemName('oppo'), equals('ColorOS'));
      expect(guard.getOemName('realme'), equals('ColorOS'));
      expect(guard.getOemName('vivo'), equals('VivoOS'));
      expect(guard.getOemName('oneplus'), equals('OxygenOS'));
      expect(guard.getOemName('huawei'), equals('EMUI/HarmonyOS'));
    });

    test('should return null OEM OS name for unknown manufacturers', () {
      expect(guard.getOemName('google'), isNull);
      expect(guard.getOemName('motorola'), isNull);
    });
  });
}
