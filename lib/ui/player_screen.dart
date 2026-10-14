import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/history.dart';
import '../l10n/strings.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.record});

  final DownloadRecord record;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  int _index = 0;
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  Future<void> _load(int index) async {
    _chewie?.dispose();
    await _video?.dispose();
    setState(() {
      _index = index;
      _chewie = null;
      _error = null;
    });

    final video = VideoPlayerController.contentUri(Uri.parse(widget.record.files[index].uri));
    _video = video;
    try {
      await video.initialize();
    } catch (_) {
      if (mounted) setState(() => _error = S.of(context).videoMissing);
      return;
    }
    if (!mounted) return;
    setState(() {
      _chewie = ChewieController(
        videoPlayerController: video,
        autoPlay: true,
        looping: true,
        aspectRatio: video.value.aspectRatio,
      );
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.record.files;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('@${widget.record.uploader}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.white70))
                  : _chewie == null
                      ? const CircularProgressIndicator()
                      : Chewie(controller: _chewie!),
            ),
          ),
          if (files.length > 1)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < files.length; i++)
                    ChoiceChip(label: Text('${i + 1}'), selected: i == _index, onSelected: (_) => _load(i)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
