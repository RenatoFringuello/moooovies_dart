import 'package:flutter/material.dart';
import '../models/movies.dart';

class FavoritesRow extends StatelessWidget {
  final List<Movies> movies;
  final Function(Movies) onTap;
  final Function(Movies) onToggleFavorite; // ← aggiungi

  const FavoritesRow({
    super.key,
    required this.movies,
    required this.onTap,
    required this.onToggleFavorite, // ← aggiungi
  });

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Text('Preferiti',
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
                        // ← cuore rosso con toggle
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () => onToggleFavorite(movie),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.favorite, color: Colors.red, size: 16),
                            ),
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