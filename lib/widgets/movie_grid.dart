import 'package:flutter/material.dart';
import '../models/movies.dart';
import 'movie_card.dart';

class MovieGrid extends StatelessWidget {
  final List<Movies> movies;
  final Set<int> favoriteIds;
  final Function(Movies) onTap;
  final Function(Movies)? onToggleFavorite;
  final bool shrinkWrap;
  final bool hasMore; // per infinite scroll
  final ScrollController? scrollController;

  const MovieGrid({
    super.key,
    required this.movies,
    required this.onTap,
    this.favoriteIds = const {},
    this.onToggleFavorite,
    this.shrinkWrap = false,
    this.hasMore = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: scrollController,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : null,
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: movies.length + (hasMore ? 2 : 0),
      itemBuilder: (_, index) {
        if (index >= movies.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final movie = movies[index];
        return MovieCard(
          movie: movie,
          isFavorite: favoriteIds.contains(movie.id),
          onTap: () => onTap(movie),
          onToggleFavorite: onToggleFavorite != null
              ? () => onToggleFavorite!(movie)
              : null,
        );
      },
    );
  }
}