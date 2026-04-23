import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/movies.dart';
import 'movie_detail_screen.dart';
import '../config/api_config.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_filters.dart';
import '../widgets/suggested_row.dart';

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
  List<Movies> _suggested = [];
  Set<int> _localMovieIds = {};
  bool _loading = false;
  bool _loadingSuggested = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  // 'discover' | 'title' | 'year' | 'person'
  String _searchMode = 'discover';
  int? _personId;
  String? _personDepartment;

  @override
  void initState() {
    super.initState();
    _loadLocalIds().then((_) {
      _fetchMovies(reset: true);
      _loadSuggested();
    });
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

  Future<void> _loadSuggested() async {
    setState(() => _loadingSuggested = true);
    try {
      final futures = [1, 2, 3].map((page) => http.get(Uri.parse(
          '$_baseUrl/3/discover/movie?api_key=$_apiKey&language=it-IT'
          '&sort_by=vote_count.desc&vote_average.gte=7'
          '&page=$page&include_adult=false')));

      final responses = await Future.wait(futures);
      final all = <Movies>[];

      for (final res in responses) {
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final results = data['results'] as List;
          for (final e in results) {
            final m = Movies.fromJson(e);
            if (!_localMovieIds.contains(m.id)) {
              all.add(m);
            }
          }
        }
      }

      all.shuffle(Random());
      setState(() {
        _suggested = all.take(20).toList();
        _loadingSuggested = false;
      });
    } catch (e) {
      print('Errore suggested: $e');
      setState(() => _loadingSuggested = false);
    }
  }

  bool get _queryIsYear =>
      RegExp(r'^\d{4}$').hasMatch(_searchController.text.trim());

  bool get _noActiveFilters =>
      _searchController.text.isEmpty && _selectedGenreId == null;

  Future<Map<String, dynamic>?> _searchPerson(String name) async {
    try {
      final res = await http.get(Uri.parse(
          '$_baseUrl/3/search/person?api_key=$_apiKey'
          '&query=${Uri.encodeComponent(name)}&language=it-IT'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final person = results[0];
          return {
            'id': person['id'] as int,
            'department':
                person['known_for_department'] as String? ?? 'Acting',
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
      Uri uri;

      switch (_searchMode) {
        case 'title':
          uri = Uri.parse(
              '$_baseUrl/3/search/movie?api_key=$_apiKey&language=it-IT'
              '&query=${Uri.encodeComponent(query)}&page=$_currentPage'
              '&include_adult=false'
              '${_selectedGenreId != null ? '&with_genres=$_selectedGenreId' : ''}');
          break;

        case 'year':
          uri = Uri.parse(
              '$_baseUrl/3/discover/movie?api_key=$_apiKey&language=it-IT'
              '&sort_by=popularity.desc&page=$_currentPage&include_adult=false'
              '&primary_release_year=$query'
              '${_selectedGenreId != null ? '&with_genres=$_selectedGenreId' : ''}');
          break;

        case 'person':
          final isActor = _personDepartment == 'Acting';
          final personParam = isActor
              ? 'with_cast=$_personId'
              : 'with_crew=$_personId';
          uri = Uri.parse(
              '$_baseUrl/3/discover/movie?api_key=$_apiKey&language=it-IT'
              '&sort_by=popularity.desc&page=$_currentPage&include_adult=false'
              '&$personParam'
              '${_selectedGenreId != null ? '&with_genres=$_selectedGenreId' : ''}');
          break;

        default:
          uri = Uri.parse(
              '$_baseUrl/3/discover/movie?api_key=$_apiKey&language=it-IT'
              '&sort_by=popularity.desc&page=$_currentPage&include_adult=false'
              '${_selectedGenreId != null ? '&with_genres=$_selectedGenreId' : ''}');
      }

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final results = data['results'] as List;
        final totalPages = data['total_pages'] as int;

        setState(() {
          final newMovies = results
              .map((e) => Movies.fromJson(e))
              .where((m) => !_localMovieIds.contains(m.id))
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
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _fetchMovies(reset: true);
    });
  }

  String get _searchModeLabel {
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
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          MovieFilters(
            searchController: _searchController,
            selectedGenreId: _selectedGenreId,
            searchHint: 'Cerca per titolo, attore, regista, anno...',
            onSearchChanged: (_) => _onFilterChanged(),
            onGenreChanged: (val) {
              setState(() => _selectedGenreId = val);
              _onFilterChanged();
            },
          ),

          // Label modalità ricerca attiva
          if (_searchController.text.isNotEmpty &&
              _searchMode != 'discover')
            Container(
              width: double.infinity,
              color: Colors.grey[900],
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                _searchModeLabel,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontStyle: FontStyle.italic),
              ),
            ),

          // Suggested (solo quando nessun filtro attivo)
          if (_noActiveFilters && !_loadingSuggested)
            SuggestedRow(
              movies: _suggested,
              onTap: (movie) => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MovieDetailScreen(movie: movie)),
              ),
            ),

          Expanded(
            child: _buildGrid()
          )
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