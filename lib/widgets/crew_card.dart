import 'package:flutter/material.dart';

class CrewCard extends StatelessWidget {
  final String name;
  final String job;
  final String? profilePath;

  const CrewCard({
    super.key,
    required this.name,
    required this.job,
    this.profilePath,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: profilePath != null
              ? Image.network(
                  'https://image.tmdb.org/t/p/w185$profilePath',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[800],
                  child: const Icon(Icons.person,
                      color: Colors.white54, size: 20),
                ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            Text(job,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}