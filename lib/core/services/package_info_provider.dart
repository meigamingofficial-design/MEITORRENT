import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'package_info_provider.g.dart';

@riverpod
Future<String> appVersion(AppVersionRef ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return '${packageInfo.version}+${packageInfo.buildNumber}';
}
