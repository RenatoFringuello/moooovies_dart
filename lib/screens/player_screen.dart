import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/api_config.dart';
import '../models/movies.dart';
import '../services/database_service.dart';

class PlayerScreen extends StatefulWidget {
  final Movies movie;
  const PlayerScreen({super.key, required this.movie});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  final DatabaseService _userService = DatabaseService();
  Timer? _saveTimer;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final url = '${ApiConfig.streamUrl}/${widget.movie.id}';
      print('URL stream: $url');

      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController.initialize();

      // Ripristina posizione salvata
      final saved = await _userService.getProgress(widget.movie.id);
      if (saved != null && saved.positionMs > 0) {
        await _videoController.seekTo(Duration(milliseconds: saved.positionMs));
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
        placeholder: const Center(child: CircularProgressIndicator()),
      );

      // Salva posizione ogni 5 secondi
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        final position = await _videoController.position;
        final duration = _videoController.value.duration;
        if (position != null && duration.inMilliseconds > 0) {
          await _userService.saveProgress(
            widget.movie.id,
            position.inMilliseconds,
            duration.inMilliseconds,
          );
        }
      });

      setState(() {});
    } catch (e) {
      print('Errore Player: $e');
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(widget.movie.title),
      ),
      body: _hasError
          ? const Center(
              child: Text('Errore nel caricamento del video',
                  style: TextStyle(color: Colors.white)),
            )
          : _chewieController != null
              ? Chewie(controller: _chewieController!)
              : const Center(child: CircularProgressIndicator()),
    );
  }
}