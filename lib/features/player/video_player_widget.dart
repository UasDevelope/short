import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../services/video_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../video_feed/video_feed_provider.dart';

class VideoPlayerWidget extends ConsumerStatefulWidget {
  final String videoId;
  final String videoUrl;
  final bool play;
  final Key? controllerKey;
  const VideoPlayerWidget({
    Key? key,
    required this.videoId,
    required this.videoUrl,
    this.play = true,
    this.controllerKey,
  }) : super(key: key);

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  File? _localFile;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    debugPrint('VideoPlayerWidget initState for videoId: ${widget.videoId}');
    _initPlayer();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('VideoPlayerWidget didUpdateWidget for videoId: ${widget.videoId}, play: ${widget.play}');
    if (widget.play != oldWidget.play) {
      if (widget.play) {
        debugPrint('Playing videoId: ${widget.videoId}');
        _controller?.play();
      } else {
        debugPrint('Pausing videoId: ${widget.videoId}');
        _controller?.pause();
      }
    }
    // Extra safety: always pause if play is false
    if (!widget.play) {
      debugPrint('Extra safety: Pausing videoId: ${widget.videoId}');
      _controller?.pause();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to feed activity state
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
      _controller!.setLooping(false);
      if (widget.play) {
        debugPrint('Auto-playing videoId: ${widget.videoId} after init');
        _controller!.play();
      }
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing video player: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    debugPrint('Disposing VideoPlayerWidget for videoId: ${widget.videoId}');
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Move ref.listen here as required by Riverpod
    ref.listen<bool>(isFeedActiveProvider, (previous, next) {
      debugPrint('Feed activity changed for videoId: ${widget.videoId}, isFeedActive: $next');
      if (next == false) {
        _controller?.pause();
      } else if (next == true && widget.play) {
        _controller?.play();
      }
    });
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