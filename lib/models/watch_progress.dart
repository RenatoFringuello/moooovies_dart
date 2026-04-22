class WatchProgress {
  final int movieId;
  final int positionMs;
  final int durationMs;
  final String lastWatched;

  WatchProgress({
    required this.movieId,
    required this.positionMs,
    required this.durationMs,
    required this.lastWatched,
  });

  double get percentage => durationMs > 0 ? positionMs / durationMs : 0;

  factory WatchProgress.fromJson(Map<String, dynamic> json) {
  return WatchProgress(
    movieId: int.parse(json['movie_id'].toString()),
    positionMs: int.parse(json['position_ms'].toString()),
    durationMs: int.parse(json['duration_ms'].toString()),
    lastWatched: json['last_watched'] ?? '',
  );
}
}