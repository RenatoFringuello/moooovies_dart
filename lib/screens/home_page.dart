import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/movies.dart';
import '../models/watch_progress.dart';
import '../services/movies_service.dart';
import '../services/database_service.dart';
import 'movie_detail_screen.dart';
import '../widgets/continue_watching_row.dart';
import '../widgets/favorites_row.dart';
import '../widgets/movie_card.dart';
import '../widgets/movie_grid.dart';

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
  List<WatchProgress> _continueWatching = [];
  List<int> _favoriteIds = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _moviesService.fetchLocalMovies(),
        _userService.getContinueWatching(),
        _userService.getFavoriteIds(),
      ]);
      setState(() {
        _allMovies = results[0] as List<Movies>;
        _continueWatching = results[1] as List<WatchProgress>;
        _favoriteIds = results[2] as List<int>;
        _loading = false;
      });
    } catch (e) {
      print('Errore _loadAll: $e');  // ← aggiungi questa riga
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  // Ricarica dopo essere tornati dal player o dal dettaglio
  void _onReturn() => _loadAll();

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

  Widget _buildAllMovies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Text('Tutti i film',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        MovieGrid(
          movies: _allMovies,
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
            MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)));
        _onReturn();
      },
      onDelete: (movie) async {  // ← aggiungi
        await _userService.deleteProgress(movie.id);
        _loadAll();
      },
    );
  }

  Widget _buildFavorites() {
    final favorites = _allMovies
        .where((m) => _favoriteIds.contains(m.id))
        .toList();

    return FavoritesRow(
      movies: favorites,
      onTap: (movie) async {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)));
        _onReturn();
      },
      onToggleFavorite: (movie) async {  // ← aggiungi
        await _userService.removeFavorite(movie.id);
        _loadAll();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, style: TextStyle(
          color: Colors.white, 
          fontWeight: FontWeight.bold
          )
        )
      ),
      body: _loading
          ? _buildShimmer()
          : _hasError
              ? const Center(
                  child: Text('Errore durante il caricamento',
                      style: TextStyle(color: Colors.white)))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildContinueWatching(),
                      _buildFavorites(),
                      _buildAllMovies(),
                    ],
                  ),
                ),
    );
  }
}