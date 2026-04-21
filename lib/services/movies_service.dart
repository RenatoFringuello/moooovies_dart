import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movies.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MoviesService {
  final String baseUrl = dotenv.env['TMDB_BASE_URL'] ?? '';
  final String apiKey = dotenv.env['TMDB_API_KEY'] ?? '';

  Future<List<Movies>> fetchMovies() async {
    final url = Uri.parse(
      '$baseUrl/3/movie/popular?api_key=$apiKey',
    );

    final response = await http.get(url);
 
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      final List results = data['results'];

      return results.map((json) => Movies.fromJson(json)).toList();
    } else {
      throw Exception('Errore API');
    }
  }
}