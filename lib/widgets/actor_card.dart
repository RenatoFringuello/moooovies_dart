import 'package:flutter/material.dart';

class ActorCard extends StatelessWidget {
  final String name;
  final String character;
  final String? profilePath;

  const ActorCard({
    super.key,
    required this.name,
    required this.character,
    this.profilePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: profilePath != null
                ? Image.network(
                    'https://image.tmdb.org/t/p/w185$profilePath',
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[800],
                    child: const Icon(Icons.person,
                        color: Colors.white54),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500),
          ),
          Text(
            character,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}