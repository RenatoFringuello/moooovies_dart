import 'package:flutter/material.dart';
import '../models/movies.dart';
import '../models/watch_progress.dart';

class ContinueWatchingRow extends StatelessWidget {
  final List<Movies> movies;
  final List<WatchProgress> progressList;
  final Function(Movies) onTap;
  final Function(Movies) onDelete; // ← aggiungi

  const ContinueWatchingRow({
    super.key,
    required this.movies,
    required this.progressList,
    required this.onTap,
    required this.onDelete, // ← aggiungi
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Text('Continua a guardare',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: movies.length,
            itemBuilder: (_, index) {
              final movie = movies[index];
              final progress = progressList.firstWhere((p) => p.movieId == movie.id);
              return GestureDetector(
                onTap: () => onTap(movie),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://image.tmdb.org/t/p/w500${movie.posterPath}',
                          fit: BoxFit.cover,
                        ),
                        // ← bottone X
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => onDelete(movie),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: progress.percentage.clamp(0.0, 1.0),
                            backgroundColor: Colors.white24,
                            color: Colors.red,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}