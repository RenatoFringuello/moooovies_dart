import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/movies.dart';
import 'movie_detail_screen.dart';
import '../utils/tmdb_genres.dart';
import '../config/api_config.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final String _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  final String _baseUrl = dotenv.env['TMDB_BASE_URL'] ?? '';

  // Filtri
  int? _selectedGenreId;
  String? _selectedYear;
  final TextEditingController _actorController = TextEditingController();
  final TextEditingController _directorController = TextEditingController();
  Timer? _debounce;

  // Risultati
  List<Movies> _movies = [];
  Set<int> _localMovieIds = {};
  bool _loading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  // Generi TMDB
  final Map<int, String> _genres = getGenreNameList();

  @override
  void initState() {
    super.initState();
    _loadLocalIds().then((_) => _fetchMovies(reset: true)); // ← modifica
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _actorController.dispose();
    _directorController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_loading &&
        _hasMore) {
      _fetchMovies();
    }
  }

  Future<void> _loadLocalIds() async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.moviesUrl));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        setState(() {
          _localMovieIds = data.map<int>((m) => m['id'] as int).toSet();
        });
      }
    } catch (e) {
      print('Errore caricamento film locali: $e');
    }
  }

  // Cerca persone su TMDB (attore o regista) → restituisce l'ID
  Future<int?> _searchPerson(String name) async {
    if (name.isEmpty) return null;
    final res = await http.get(Uri.parse(
        '$_baseUrl/3/search/person?api_key=$_apiKey&query=${Uri.encodeComponent(name)}'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final results = data['results'] as List;
      if (results.isNotEmpty) return results[0]['id'];
    }
    return null;
  }

  Future<void> _fetchMovies({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);

    if (reset) {
      _currentPage = 1;
      _hasMore = true;
      _movies = [];
    }

    try {
      // Risolvi attore/regista in ID se necessario
      final actorId = await _searchPerson(_actorController.text.trim());
      final directorId = await _searchPerson(_directorController.text.trim());

      // Costruisci query params
      final params = <String, String>{
        'api_key': _apiKey,
        'language': 'it-IT',
        'sort_by': 'popularity.desc',
        'page': '$_currentPage',
        'include_adult': 'false',
      };

      if (_selectedGenreId != null) {
        params['with_genres'] = '$_selectedGenreId';
      }
      if (_selectedYear != null && _selectedYear!.isNotEmpty) {
        params['primary_release_year'] = _selectedYear!;
      }
      if (actorId != null) {
        params['with_cast'] = '$actorId';
      }
      if (directorId != null) {
        params['with_crew'] = '$directorId';
      }

      final uri = Uri.parse('$_baseUrl/3/discover/movie')
          .replace(queryParameters: params);

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List;
        final totalPages = data['total_pages'] as int;

        setState(() {
          final newMovies = results
              .map((e) => Movies.fromJson(e))
              .where((m) => !_localMovieIds.contains(m.id)) // ← filtro
              .toList();
          _movies.addAll(newMovies);
          _currentPage++;
          _hasMore = _currentPage <= totalPages;
        });
      }
    } catch (e) {
      print('Errore explore: $e');
    }

    setState(() => _loading = false);
  }

  void _onFilterChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _fetchMovies(reset: true);
    });
  }

  // ── ANNI ────────────────────────────────────────────
  List<String> get _years {
    final now = DateTime.now().year;
    return List.generate(40, (i) => '${now - i}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Esploooora', style: TextStyle(
          color: Colors.white, 
          fontWeight: FontWeight.bold
          )
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          // Riga 1: Genere + Anno
          Row(
            children: [
              // Genere
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedGenreId,
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration(''),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tutti i generi')),
                    ..._genres.entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedGenreId = val);
                    _onFilterChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Anno
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedYear,
                  dropdownColor: Colors.grey[900],
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration(''),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tutti gli anni')),
                    ..._years.map((y) => DropdownMenuItem(
                          value: y,
                          child: Text(y),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedYear = val);
                    _onFilterChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Riga 2: Attore + Regista
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _actorController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration('Attore'),
                  onChanged: (_) => _onFilterChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _directorController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration('Regista'),
                  onChanged: (_) => _onFilterChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
      filled: true,
      fillColor: Colors.grey[800],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildGrid() {
    if (_loading && _movies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_movies.isEmpty) {
      return const Center(
        child: Text('Nessun film trovato',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _movies.length + (_hasMore ? 2 : 0),
      itemBuilder: (_, index) {
        // Loading indicator in fondo
        if (index >= _movies.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final movie = _movies[index];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MovieDetailScreen(movie: movie)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                movie.posterPath.isNotEmpty
                    ? Image.network(
                        'https://image.tmdb.org/t/p/w500${movie.posterPath}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.movie,
                              color: Colors.white54, size: 40),
                        ),
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.movie,
                            color: Colors.white54, size: 40),
                      ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                // Voto in alto a destra
                if (movie.voteAverage > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              color: Colors.amber, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            movie.rating,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}