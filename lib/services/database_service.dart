import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/watch_progress.dart';
import 'device_service.dart';

class DatabaseService {
  // ── PROGRESS ──────────────────────────────────────

  Future<void> saveProgress(int movieId, int positionMs, int durationMs) async {
    final deviceId = await DeviceService.getDeviceId();
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

  Future<void> deleteProgress(int movieId) async {
    final deviceId = await DeviceService.getDeviceId();
    await http.delete(
      Uri.parse(ApiConfig.progressUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'deviceId': deviceId, 'movieId': movieId}),
    );
  }

  Future<WatchProgress?> getProgress(int movieId) async {
    final deviceId = await DeviceService.getDeviceId();
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
    final deviceId = await DeviceService.getDeviceId();
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
    final deviceId = await DeviceService.getDeviceId();
    await http.post(
      Uri.parse(ApiConfig.favoritesUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'deviceId': deviceId, 'movieId': movieId}),
    );
  }

  Future<void> removeFavorite(int movieId) async {
    final deviceId = await DeviceService.getDeviceId();
    await http.delete(
      Uri.parse(ApiConfig.favoritesUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'deviceId': deviceId, 'movieId': movieId}),
    );
  }

  Future<bool> isFavorite(int movieId) async {
    final deviceId = await DeviceService.getDeviceId();
    final res = await http.get(
      Uri.parse('${ApiConfig.favoritesUrl}/$deviceId/$movieId'),
    );
    if (res.statusCode == 200) {
      return json.decode(res.body)['isFavorite'] ?? false;
    }
    return false;
  }

  Future<List<int>> getFavoriteIds() async {
    final deviceId = await DeviceService.getDeviceId();
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