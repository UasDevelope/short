import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

class VideoTrimmerWidget extends StatefulWidget {
  final String videoPath;
  final void Function(String trimmedPath, Duration start, Duration end) onVideoTrimmed;
  
  const VideoTrimmerWidget({
    Key? key, 
    required this.videoPath, 
    required this.onVideoTrimmed
  }) : super(key: key);

  @override
  State<VideoTrimmerWidget> createState() => _VideoTrimmerWidgetState();
}

class _VideoTrimmerWidgetState extends State<VideoTrimmerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  Duration _startTime = Duration.zero;
  Duration _endTime = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isTrimming = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoPath));
      await _controller!.initialize();
      
      setState(() {
        _isInitialized = true;
        _totalDuration = _controller!.value.duration;
        _endTime = _totalDuration;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading video: $e')),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _trimVideo() async {
    if (_isTrimming) return;

    setState(() {
      _isTrimming = true;
    });

    try {
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        widget.videoPath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );

      if (mediaInfo?.file != null) {
        widget.onVideoTrimmed(
          mediaInfo!.file!.path,
          _startTime,
          _endTime,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video processed successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing video: $e')),
      );
    } finally {
      setState(() {
        _isTrimming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Text(
                'Start: ${_startTime.inSeconds}s, End: ${_endTime.inSeconds}s',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              RangeSlider(
                min: 0.0,
                max: _totalDuration.inSeconds.toDouble(),
                values: RangeValues(
                  _startTime.inSeconds.toDouble(),
                  _endTime.inSeconds.toDouble(),
                ),
                onChanged: (values) {
                  setState(() {
                    _startTime = Duration(seconds: values.start.toInt());
                    _endTime = Duration(seconds: values.end.toInt());
                  });
                  
                  if (_controller != null) {
                    _controller!.seekTo(_startTime);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
              onPressed: () => _controller?.play(),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
              onPressed: () => _controller?.pause(),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
              onPressed: () => _controller?.seekTo(Duration.zero),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: _isTrimming 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.content_cut),
          label: Text(_isTrimming ? 'Processing...' : 'Process Video'),
          onPressed: _isTrimming ? null : _trimVideo,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
} 