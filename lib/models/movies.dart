class Movies {
  final String title;
  final String posterPath;

  Movies({
    required this.title,
    required this.posterPath,
  });

  factory Movies.fromJson(Map<String, dynamic> json) {
    return Movies(
      title: json['title'] ?? '',
      posterPath: json['poster_path'] ?? '',
    );
  }
}