import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/movies.dart';
import 'movie_detail_screen.dart';
import '../config/api_config.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_filters.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final String _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  final String _baseUrl = dotenv.env['TMDB_BASE_URL'] ?? '';

  int? _selectedGenreId;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Movies> _movies = [];
  Set<int> _localMovieIds = {};
  bool _loading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  // Tiene traccia del tipo di ricerca attiva
  // 'title' | 'year' | 'person' | 'discover'
  String _searchMode = 'discover';
  int? _personId; // ID persona trovata su TMDB
  String? _personDepartment; // 'Acting' o 'Directing'

  @override
  void initState() {
    super.initState();
    _loadLocalIds().then((_) => _fetchMovies(reset: true));
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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
      print('Errore film locali: $e');
    }
  }

  bool get _queryIsYear =>
      RegExp(r'^\d{4}$').hasMatch(_searchController.text.trim());

  // Cerca persona su TMDB — restituisce (id, department) o null
  // Sostituisci questo metodo
  Future<Map<String, dynamic>?> _searchPerson(String name) async {
    try {
      final res = await http.get(Uri.parse(
          '$_baseUrl/3/search/person?api_key=$_apiKey&query=${Uri.encodeComponent(name)}&language=it-IT'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final person = results[0];
          return {
            'id': person['id'] as int,
            'department': person['known_for_department'] as String? ?? 'Acting',
          };
        }
      }
    } catch (e) {
      print('Errore ricerca persona: $e');
    }
    return null;
  }

  Future<void> _resolveSearchMode() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      _searchMode = 'discover';
      _personId = null;
      _personDepartment = null;
      return;
    }

    if (_queryIsYear) {
      _searchMode = 'year';
      _personId = null;
      _personDepartment = null;
      return;
    }

    final person = await _searchPerson(query);
    if (person != null) {
      _searchMode = 'person';
      _personId = person['id'] as int;
      _personDepartment = person['department'] as String;
    } else {
      _searchMode = 'title';
      _personId = null;
      _personDepartment = null;
    }
  }

  Future<void> _fetchMovies({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);

    if (reset) {
      _currentPage = 1;
      _hasMore = true;
      _movies = [];
      await _resolveSearchMode();
    }

    try {
      final query = _searchController.text.trim();
      List<Uri> uris = [];

      switch (_searchMode) {
        case 'title':
          // Ricerca per titolo
          uris = [
            Uri.parse('$_baseUrl/3/search/movie').replace(
              queryParameters: {
                'api_key': _apiKey,
                'language': 'it-IT',
                'query': query,
                'page': '$_currentPage',
                'include_adult': 'false',
                if (_selectedGenreId != null)
                  'with_genres': '$_selectedGenreId',
              },
            )
          ];
          break;

        case 'year':
          // Discover con anno
          uris = [
            Uri.parse('$_baseUrl/3/discover/movie').replace(
              queryParameters: {
                'api_key': _apiKey,
                'language': 'it-IT',
                'sort_by': 'popularity.desc',
                'page': '$_currentPage',
                'include_adult': 'false',
                'primary_release_year': query,
                if (_selectedGenreId != null)
                  'with_genres': '$_selectedGenreId',
              },
            )
          ];
          break;

        case 'person':
          // Discover con persona — cast E crew separati poi merged
          final isActor = _personDepartment == 'Acting';
          uris = [
            Uri.parse('$_baseUrl/3/discover/movie').replace(
              queryParameters: {
                'api_key': _apiKey,
                'language': 'it-IT',
                'sort_by': 'popularity.desc',
                'page': '$_currentPage',
                'include_adult': 'false',
                if (isActor) 'with_cast': '$_personId',
                if (!isActor) 'with_crew': '$_personId',
                if (_selectedGenreId != null)
                  'with_genres': '$_selectedGenreId',
              },
            )
          ];
          break;

        default:
          // Discover generico
          uris = [
            Uri.parse('$_baseUrl/3/discover/movie').replace(
              queryParameters: {
                'api_key': _apiKey,
                'language': 'it-IT',
                'sort_by': 'popularity.desc',
                'page': '$_currentPage',
                'include_adult': 'false',
                if (_selectedGenreId != null)
                  'with_genres': '$_selectedGenreId',
              },
            )
          ];
      }

      // Esegui tutte le richieste
      final responses = await Future.wait(uris.map((u) => http.get(u)));

      // Merge e deduplicazione per ID
      final seen = <int>{};
      final allMovies = <Movies>[];
      int maxPages = 1;

      for (final res in responses) {
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final results = data['results'] as List;
          final totalPages = data['total_pages'] as int;
          if (totalPages > maxPages) maxPages = totalPages;

          for (final e in results) {
            final m = Movies.fromJson(e);
            if (!seen.contains(m.id) && !_localMovieIds.contains(m.id)) {
              seen.add(m.id);
              allMovies.add(m);
            }
          }
        }
      }

      setState(() {
        _movies.addAll(allMovies);
        _currentPage++;
        _hasMore = _currentPage <= maxPages;
      });
    } catch (e) {
      print('Errore explore: $e');
    }

    setState(() => _loading = false);
  }

  void _onFilterChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _fetchMovies(reset: true);
    });
  }

  // Label sotto la barra di ricerca che mostra la modalità attiva
  String get _searchHint {
    switch (_searchMode) {
      case 'person':
        final role =
            _personDepartment == 'Acting' ? 'attore/attrice' : 'regista';
        return 'Ricerca per $role: ${_searchController.text.trim()}';
      case 'year':
        return 'Ricerca per anno: ${_searchController.text.trim()}';
      case 'title':
        return 'Ricerca per titolo: ${_searchController.text.trim()}';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Esploooora',
          style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          MovieFilters(
            searchController: _searchController,
            selectedGenreId: _selectedGenreId,
            onSearchChanged: (_) => _onFilterChanged(),
            onGenreChanged: (val) {
              setState(() => _selectedGenreId = val);
              _onFilterChanged();
            },
          ),
          // Label modalità ricerca attiva
          if (_searchMode != 'discover' &&
              _searchController.text.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.grey[900],
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                _searchHint,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontStyle: FontStyle.italic),
              ),
            ),
          Expanded(child: _buildGrid()),
        ],
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
    return MovieGrid(
      movies: _movies,
      onTap: (movie) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => MovieDetailScreen(movie: movie)),
      ),
      hasMore: _hasMore,
      scrollController: _scrollController,
    );
  }
}