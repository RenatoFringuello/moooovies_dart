import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  static String? _deviceId;

  static Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      _deviceId = ios.identifierForVendor ?? 'unknown-ios';
    } else if (Platform.isMacOS) {
      final mac = await deviceInfo.macOsInfo;
      _deviceId = mac.systemGUID ?? 'unknown-mac';
    } else if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      _deviceId = android.id;
    } else {
      _deviceId = 'unknown-device';
    }
    return _deviceId!;
  }
}