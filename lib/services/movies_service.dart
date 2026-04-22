import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movies.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/api_config.dart';

class MoviesService {
  final String baseUrl = dotenv.env['TMDB_BASE_URL'] ?? '';
  final String apiKey = dotenv.env['TMDB_API_KEY'] ?? '';

  Future<List<Movies>> fetchLocalMovies() async {
    final url = Uri.parse(ApiConfig.moviesUrl);
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List results = json.decode(response.body);
      return results.map((json) => Movies.fromJson(json)).toList();
    } else {
      throw Exception('Errore server locale');
    }
  }
}