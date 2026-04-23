import 'package:flutter/material.dart';
import '../utils/tmdb_genres.dart';

class MovieFilters extends StatefulWidget {
  final TextEditingController searchController;
  final int? selectedGenreId;
  final Function(String) onSearchChanged;
  final Function(int?) onGenreChanged;

  const MovieFilters({
    super.key,
    required this.searchController,
    required this.selectedGenreId,
    required this.onSearchChanged,
    required this.onGenreChanged,
  });

  @override
  State<MovieFilters> createState() => _MovieFiltersState();
}

class _MovieFiltersState extends State<MovieFilters> {
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
      filled: true,
      fillColor: Colors.grey[800],
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          // ── BARRA DI RICERCA ──────────────────────────
          TextField(
            controller: widget.searchController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cerca per titolo, attore, regista, anno...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
              filled: true,
              fillColor: Colors.grey[800],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white54, size: 20),
              suffixIcon: widget.searchController.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        widget.searchController.clear();
                        widget.onSearchChanged('');
                        setState(() {});
                      },
                      child: const Icon(Icons.close,
                          color: Colors.white54, size: 18),
                    )
                  : null,
            ),
            onChanged: (val) {
              widget.onSearchChanged(val);
              setState(() {});
            },
          ),

          const SizedBox(height: 10),

          // ── GENERE ────────────────────────────────────
          DropdownButtonFormField<int>(
            value: widget.selectedGenreId,
            dropdownColor: Colors.grey[900],
            isExpanded: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration(''),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Tutti i generi')),
              ...tmdbGenres.entries.map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  )),
            ],
            onChanged: widget.onGenreChanged,
          ),
        ],
      ),
    );
  }
}