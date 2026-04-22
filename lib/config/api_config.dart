class ApiConfig {
  static const String localIp = '127.0.0.1';
  static const int serverPort = 3000;
  static const String baseUrl = 'http://$localIp:$serverPort';
  static const String streamUrl = '$baseUrl/stream';
  static const String moviesUrl = '$baseUrl/movies';
  static const String progressUrl = '$baseUrl/progress';
  static const String favoritesUrl = '$baseUrl/favorites';
}