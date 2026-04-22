import 'dart:convert';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/movies.dart';
import '../services/database_service.dart';
import '../utils/tmdb_genres.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Movies movie;
  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final DatabaseService _db = DatabaseService();
  final String _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  final String _baseUrl = dotenv.env['TMDB_BASE_URL'] ?? '';

  bool _isFavorite = false;
  bool _loadingFavorite = true;

  // Dati aggiuntivi TMDB
  Map<String, dynamic>? _details;
  List<dynamic> _cast = [];
  List<dynamic> _crew = [];
  List<dynamic> _trailers = [];
  List<dynamic> _backdrops = [];
  bool _loadingExtra = true;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
    _loadExtraDetails();
  }

  Future<void> _loadFavorite() async {
    final result = await _db.isFavorite(widget.movie.id);
    setState(() {
      _isFavorite = result;
      _loadingFavorite = false;
    });
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await _db.removeFavorite(widget.movie.id);
    } else {
      await _db.addFavorite(widget.movie.id);
    }
    setState(() => _isFavorite = !_isFavorite);
  }

  Future<void> _loadExtraDetails() async {
    try {
      final id = widget.movie.id;
      final lang = 'it-IT';

      final results = await Future.wait([
        http.get(Uri.parse('$_baseUrl/3/movie/$id?api_key=$_apiKey&language=$lang')),
        http.get(Uri.parse('$_baseUrl/3/movie/$id/credits?api_key=$_apiKey&language=$lang')),
        http.get(Uri.parse('$_baseUrl/3/movie/$id/videos?api_key=$_apiKey&language=$lang')),
        http.get(Uri.parse('$_baseUrl/3/movie/$id/images?api_key=$_apiKey')),
      ]);

      final details = json.decode(results[0].body);
      final credits = json.decode(results[1].body);
      final videos = json.decode(results[2].body);
      final images = json.decode(results[3].body);

      // Se non ci sono trailer in italiano, cerca in inglese
      List<dynamic> trailers = (videos['results'] as List)
          .where((v) => v['type'] == 'Trailer' && v['site'] == 'YouTube')
          .toList();

      if (trailers.isEmpty) {
        final enVideos = await http.get(Uri.parse(
            '$_baseUrl/3/movie/$id/videos?api_key=$_apiKey&language=en-US'));
        final enData = json.decode(enVideos.body);
        trailers = (enData['results'] as List)
            .where((v) => v['type'] == 'Trailer' && v['site'] == 'YouTube')
            .toList();
      }

      setState(() {
        _details = details;
        _cast = (credits['cast'] as List).take(15).toList();
        _crew = (credits['crew'] as List)
            .where((c) =>
                c['job'] == 'Director' ||
                c['job'] == 'Screenplay' ||
                c['job'] == 'Producer')
            .toList();
        _trailers = trailers;
        _backdrops = (images['backdrops'] as List).take(10).toList();
        _loadingExtra = false;
      });
    } catch (e) {
      print('Errore dettagli: $e');
      setState(() => _loadingExtra = false);
    }
  }

  Future<void> _openTrailer(String key) async {
    final url = Uri.parse('https://www.youtube.com/watch?v=$key');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    final genres = movie.genreIds
        .map((id) => getGenreName(id))
        .where((g) => g.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // ── HERO ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 420,
            pinned: true,
            backgroundColor: Colors.black,
            actions: [
              _loadingFavorite
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)),
                    )
                  : IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.white,
                      ),
                      onPressed: _toggleFavorite,
                    ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    movie.backdropPath.isNotEmpty
                        ? 'https://image.tmdb.org/t/p/w780${movie.backdropPath}'
                        : 'https://image.tmdb.org/t/p/w500${movie.posterPath}',
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black, Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── TITOLO ──────────────────────
                      Text(movie.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),
                      if (movie.originalTitle.isNotEmpty &&
                          movie.originalTitle != movie.title)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(movie.originalTitle,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 14)),
                        ),

                      const SizedBox(height: 12),

                      // ── METADATI ────────────────────
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          if (movie.year.isNotEmpty)
                            _InfoChip(
                                icon: Icons.calendar_today,
                                label: movie.year),
                          if (movie.voteAverage > 0)
                            _InfoChip(
                                icon: Icons.star,
                                label:
                                    '${movie.rating} (${movie.voteCount})',
                                color: Colors.amber),
                          if (movie.originalLanguage.isNotEmpty)
                            _InfoChip(
                                icon: Icons.language,
                                label: movie.originalLanguage
                                    .toUpperCase()),
                          // Durata dai dettagli
                          if (_details?['runtime'] != null &&
                              _details!['runtime'] > 0)
                            _InfoChip(
                                icon: Icons.timer,
                                label:
                                    '${_details!['runtime']} min'),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── GENERI ──────────────────────
                      if (genres.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: genres
                              .map((g) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.white30),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Text(g,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                  ))
                              .toList(),
                        ),

                      const SizedBox(height: 20),

                      // ── BOTTONE PLAY ────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    PlayerScreen(movie: movie)),
                          ),
                          icon: const Icon(Icons.play_arrow,
                              color: Colors.black),
                          label: const Text('Play',
                              style: TextStyle(
                                  color: Colors.black, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── TRAMA ───────────────────────
                      if (movie.overview != null &&
                          movie.overview!.isNotEmpty) ...[
                        const Text('Trama',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(movie.overview!,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5)),
                      ],
                    ],
                  ),
                ),

                if (_loadingExtra)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child:
                        Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  // ── TRAILER ─────────────────────────
                  if (_trailers.isNotEmpty) ...[
                    _SectionTitle('Trailer'),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        itemCount: _trailers.length,
                        itemBuilder: (_, i) {
                          final trailer = _trailers[i];
                          return GestureDetector(
                            onTap: () =>
                                _openTrailer(trailer['key']),
                            child: Container(
                              width: 160,
                              margin:
                                  const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(10),
                                image: DecorationImage(
                                  image: NetworkImage(
                                      'https://img.youtube.com/vi/${trailer['key']}/hqdefault.jpg'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  color: Colors.black45,
                                ),
                                child: const Center(
                                  child: Icon(
                                      Icons.play_circle_fill,
                                      color: Colors.white,
                                      size: 40),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // ── FOTO ────────────────────────────
                  if (_backdrops.isNotEmpty) ...[
                    _SectionTitle('Foto'),
                    CarouselSlider(
                      options: CarouselOptions(
                        height: 200,
                        viewportFraction: 0.85,
                        enlargeCenterPage: true,
                        enableInfiniteScroll: false,
                      ),
                      items: _backdrops.map((b) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            'https://image.tmdb.org/t/p/w780${b['file_path']}',
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // ── CAST ────────────────────────────
                  if (_cast.isNotEmpty) ...[
                    _SectionTitle('Cast'),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        itemCount: _cast.length,
                        itemBuilder: (_, i) {
                          final actor = _cast[i];
                          return Container(
                            width: 90,
                            margin:
                                const EdgeInsets.only(right: 12),
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(50),
                                  child: actor['profile_path'] !=
                                          null
                                      ? Image.network(
                                          'https://image.tmdb.org/t/p/w185${actor['profile_path']}',
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.grey[800],
                                          child: const Icon(
                                              Icons.person,
                                              color: Colors.white54),
                                        ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  actor['name'] ?? '',
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  actor['character'] ?? '',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // ── CREW ────────────────────────────
                  if (_crew.isNotEmpty) ...[
                    _SectionTitle('Crew'),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: _crew.map((c) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(20),
                                child: c['profile_path'] != null
                                    ? Image.network(
                                        'https://image.tmdb.org/t/p/w185${c['profile_path']}',
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.grey[800],
                                        child: const Icon(
                                            Icons.person,
                                            color: Colors.white54,
                                            size: 20),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(c['name'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w500)),
                                  Text(c['job'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11)),
                                ],
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── WIDGETS HELPER ────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(title,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}