import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meitorrent/core/services/shared_preferences_provider.dart';
import 'package:meitorrent/features/settings/presentation/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Battery Optimization Tile Widget Tests', () {
    setUp(() {
      // Initialize SharedPreferences mock with default empty values
      SharedPreferences.setMockInitialValues({});

      // Stub DeviceInfoPlugin & FlutterForegroundTask platform channels to avoid MissingPluginException
      const MethodChannel('plugins.flutter.io/device_info')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        return <String, dynamic>{
          'manufacturer': 'Xiaomi',
          'model': 'Mi 11',
          'brand': 'Xiaomi',
          'isPhysicalDevice': true,
          'version': <String, dynamic>{'sdkInt': 30},
        };
      });

      const MethodChannel('dev.fluttercommunity.plus/device_info')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        return <String, dynamic>{
          'manufacturer': 'Xiaomi',
          'model': 'Mi 11',
          'brand': 'Xiaomi',
          'isPhysicalDevice': true,
          'version': <String, dynamic>{'sdkInt': 30},
        };
      });

      const MethodChannel('com.pravera.flutter_foreground_task/methods')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'isIgnoringBatteryOptimizations') {
          return false; // Optimizations not yet ignored
        }
        return null;
      });
    });

    tearDown(() {
      const MethodChannel('plugins.flutter.io/device_info').setMockMethodCallHandler(null);
      const MethodChannel('dev.fluttercommunity.plus/device_info').setMockMethodCallHandler(null);
      const MethodChannel('com.pravera.flutter_foreground_task/methods').setMockMethodCallHandler(null);
    });

    testWidgets('should render SettingsScreen and display Battery Optimization Tile', (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Allow asynchronous microtasks, futures, and animations to fully resolve
      await tester.pumpAndSettle();

      // Verify that the title of the tile is displayed (even if offstage in ListView)
      expect(
        find.text('Ignore Battery Optimizations', skipOffstage: false),
        findsOneWidget,
      );

      // Verify that the expected subtitle is displayed
      expect(
        find.text('Battery optimizations are disabled', skipOffstage: false),
        findsOneWidget,
      );

      // Verify the performance section header is present
      expect(
        find.text('PERFORMANCE', skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}
