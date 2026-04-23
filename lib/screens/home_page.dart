import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/movies.dart';
import '../models/watch_progress.dart';
import '../services/movies_service.dart';
import '../services/database_service.dart';
import 'movie_detail_screen.dart';
import '../widgets/continue_watching_row.dart';
import '../widgets/favorites_row.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_filters.dart';
import '../widgets/suggested_row.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MoviesService _moviesService = MoviesService();
  final DatabaseService _userService = DatabaseService();

  List<Movies> _allMovies = [];
  List<Movies> _suggested = [];
  List<WatchProgress> _continueWatching = [];
  List<int> _favoriteIds = [];
  String _searchQuery = '';
  int? _selectedGenreId;
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _moviesService.fetchLocalMovies(),
        _userService.getContinueWatching(),
        _userService.getFavoriteIds(),
      ]);
      final movies = results[0] as List<Movies>;
      setState(() {
        _allMovies = movies;
        _continueWatching = results[1] as List<WatchProgress>;
        _favoriteIds = results[2] as List<int>;
        _loading = false;
      });
      _refreshSuggested(movies);
    } catch (e) {
      print('Errore _loadAll: $e');
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  void _refreshSuggested(List<Movies> movies) {
    final rated = movies.where((m) => m.voteAverage > 5).toList();
    rated.shuffle(Random());
    setState(() {
      _suggested = rated.take(20).toList();
    });
  }

  void _onReturn() => _loadAll();

  bool get _queryIsYear =>
      RegExp(r'^\d{4}$').hasMatch(_searchQuery.trim());

  List<Movies> get _getFilteredMovies {
    final query = _searchQuery.trim().toLowerCase();

    return _allMovies.where((movie) {
      final matchesGenre = _selectedGenreId == null ||
          movie.genreIds.contains(_selectedGenreId);

      bool matchesSearch = true;
      if (query.isNotEmpty) {
        if (_queryIsYear) {
          matchesSearch = movie.year == _searchQuery.trim();
        } else {
          matchesSearch =
              movie.title.toLowerCase().contains(query) ||
              movie.originalTitle.toLowerCase().contains(query) ||
              movie.castNames.any((n) => n.contains(query)) ||
              movie.crewNames.any((n) => n.contains(query));
        }
      }

      return matchesGenre && matchesSearch;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _selectedGenreId != null;

  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[800]!,
        highlightColor: Colors.grey[600]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueWatching() {
    final inProgress = _continueWatching
        .map((p) => _allMovies.firstWhere(
              (m) => m.id == p.movieId,
              orElse: () => Movies(id: -1, title: '', posterPath: ''),
            ))
        .where((m) => m.id != -1)
        .toList();

    return ContinueWatchingRow(
      movies: inProgress,
      progressList: _continueWatching,
      onTap: (movie) async {
        await Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => MovieDetailScreen(movie: movie)));
        _onReturn();
      },
      onDelete: (movie) async {
        await _userService.deleteProgress(movie.id);
        _loadAll();
      },
    );
  }

  Widget _buildFavorites() {
    final favorites =
        _allMovies.where((m) => _favoriteIds.contains(m.id)).toList();

    return FavoritesRow(
      movies: favorites,
      onTap: (movie) async {
        await Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => MovieDetailScreen(movie: movie)));
        _onReturn();
      },
      onToggleFavorite: (movie) async {
        await _userService.removeFavorite(movie.id);
        _loadAll();
      },
    );
  }

  Widget _buildAllMovies() {
    final movies = _hasActiveFilters ? _getFilteredMovies : _allMovies;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Text(
            _hasActiveFilters
                ? 'Risultati (${movies.length})'
                : 'Tutti i film',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
        ),
        if (movies.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('Nessun film trovato',
                  style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          MovieGrid(
            movies: movies,
            favoriteIds: _favoriteIds.toSet(),
            shrinkWrap: true,
            onTap: (movie) async {
              await Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => MovieDetailScreen(movie: movie)));
              _onReturn();
            },
            onToggleFavorite: (movie) async {
              if (_favoriteIds.contains(movie.id)) {
                await _userService.removeFavorite(movie.id);
              } else {
                await _userService.addFavorite(movie.id);
              }
              _loadAll();
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? _buildShimmer()
          : _hasError
              ? const Center(
                  child: Text('Errore durante il caricamento',
                      style: TextStyle(color: Colors.white)))
              : Column(
                  children: [
                    MovieFilters(
                      searchController: _searchController,
                      selectedGenreId: _selectedGenreId,
                      searchHint: 'Cerca per titolo, attore, regista, anno...',
                      onSearchChanged: (val) =>
                          setState(() => _searchQuery = val),
                      onGenreChanged: (val) =>
                          setState(() => _selectedGenreId = val),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_hasActiveFilters) ...[
                              _buildContinueWatching(),
                              _buildFavorites(),
                              SuggestedRow(
                                movies: _suggested,
                                onTap: (movie) async {
                                  await Navigator.push(context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              MovieDetailScreen(movie: movie)));
                                  _onReturn();
                                },
                              ),
                            ],
                            _buildAllMovies(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}