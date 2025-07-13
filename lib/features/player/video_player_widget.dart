import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../services/video_cache_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoId;
  final String videoUrl;
  const VideoPlayerWidget({Key? key, required this.videoId, required this.videoUrl}) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  File? _localFile;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final cacheService = VideoCacheService();
    if (await cacheService.isCached(widget.videoId)) {
      _localFile = File(await cacheService.getCachedFilePath(widget.videoId));
    } else {
      cacheService.cacheVideo(widget.videoId, widget.videoUrl); // Download in background
    }

    try {
      _controller = _localFile != null 
        ? VideoPlayerController.file(_localFile!)
        : VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.play();
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing video player: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller!),
          // Play/Pause overlay
          GestureDetector(
            onTap: () {
              setState(() {
                _controller!.value.isPlaying
                    ? _controller!.pause()
                    : _controller!.play();
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _controller!.value.isPlaying ? 0.0 : 0.7,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 