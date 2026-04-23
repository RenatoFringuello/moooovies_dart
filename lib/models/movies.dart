class Movies {
  final int id;
  final String title;
  final String originalTitle;
  final String posterPath;
  final String backdropPath;
  final String? overview;
  final String? localPath;
  final String releaseDate;
  final double voteAverage;
  final int voteCount;
  final String originalLanguage;
  final List<int> genreIds;
  final List<String> castNames;
  final List<String> crewNames;

  Movies({
    required this.id,
    required this.title,
    this.originalTitle = '',
    required this.posterPath,
    this.backdropPath = '',
    this.overview,
    this.localPath,
    this.releaseDate = '',
    this.voteAverage = 0,
    this.voteCount = 0,
    this.originalLanguage = '',
    this.genreIds = const [],
    this.castNames = const [],
    this.crewNames = const [],
  });

  String get year =>
      releaseDate.isNotEmpty ? releaseDate.substring(0, 4) : '';
  String get rating => voteAverage.toStringAsFixed(1);

  factory Movies.fromJson(Map<String, dynamic> json) {
    return Movies(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      originalTitle: json['original_title'] ?? '',
      posterPath: json['poster_path'] ?? '',
      backdropPath: json['backdrop_path'] ?? '',
      overview: json['overview'] ?? '',
      localPath: json['localPath'] ?? json['local_path'] ?? '',
      releaseDate: json['release_date'] ?? '',
      voteAverage: (json['vote_average'] ?? 0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      originalLanguage: json['original_language'] ?? '',
      genreIds: List<int>.from(json['genre_ids'] ?? []),
      castNames: List<String>.from(json['cast_names'] ?? []),
      crewNames: List<String>.from(json['crew_names'] ?? []),
    );
  }
}