import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/movies.dart';
import '../models/watch_progress.dart';

class UserService {
  static String? _deviceId;

  // Recupera o genera un deviceId univoco
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

  // ── PROGRESS ──────────────────────────────────────

  Future<void> saveProgress(int movieId, int positionMs, int durationMs) async {
    final deviceId = await getDeviceId();
    await http.post(
      Uri.parse(ApiConfig.progressUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'deviceId': deviceId,
        'movieId': movieId,
        'positionMs': positionMs,
        'durationMs': durationMs,
      }),
    );
  }

  Future<WatchProgress?> getProgress(int movieId) async {
    final deviceId = await getDeviceId();
    final res = await http.get(
      Uri.parse('${ApiConfig.progressUrl}/$deviceId/$movieId'),
    );
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['position_ms'] == 0) return null;
      return WatchProgress.fromJson(data);
    }
    return null;
  }

  Future<List<WatchProgress>> getContinueWatching() async {
    final deviceId = await getDeviceId();
    final res = await http.get(
      Uri.parse('${ApiConfig.progressUrl}/$deviceId'),
    );
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.map((e) => WatchProgress.fromJson(e)).toList();
    }
    return [];
  }

  // ── FAVORITES ─────────────────────────────────────

  Future<void> addFavorite(int movieId) async {
    final deviceId = await getDeviceId();
    await http.post(
      Uri.parse(ApiConfig.favoritesUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'deviceId': deviceId, 'movieId': movieId}),
    );
  }

  Future<void> removeFavorite(int movieId) async {
    final deviceId = await getDeviceId();
    await http.delete(
      Uri.parse(ApiConfig.favoritesUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'deviceId': deviceId, 'movieId': movieId}),
    );
  }

  Future<bool> isFavorite(int movieId) async {
    final deviceId = await getDeviceId();
    final res = await http.get(
      Uri.parse('${ApiConfig.favoritesUrl}/$deviceId/$movieId'),
    );
    if (res.statusCode == 200) {
      return json.decode(res.body)['isFavorite'] ?? false;
    }
    return false;
  }

  Future<List<int>> getFavoriteIds() async {
    final deviceId = await getDeviceId();
    final res = await http.get(
      Uri.parse('${ApiConfig.favoritesUrl}/$deviceId'),
    );
    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      return data.map<int>((e) => e['movie_id'] as int).toList();
    }
    return [];
  }
}