import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/history.dart';
import '../l10n/strings.dart';
import '../state/providers.dart';
import 'player_screen.dart';

class HistoryTile extends ConsumerWidget {
  const HistoryTile({super.key, required this.record});

  final DownloadRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = S.of(context);
    final thumb = record.thumbnailPath;
    final subtitle = [
      DateFormat('d MMM, h:mm a').format(record.createdAt),
      _formatSize(record.totalSize),
      if (record.files.length > 1) s.nVideos(record.files.length),
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _play(context),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 96,
              child: thumb != null && File(thumb).existsSync()
                  ? Image.file(File(thumb), fit: BoxFit.cover)
                  : ColoredBox(color: scheme.surfaceContainerHighest, child: const Icon(Icons.movie_outlined)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${record.uploader}', style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) => _onAction(context, ref, action),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'play', child: Text(s.play)),
                PopupMenuItem(value: 'open', child: Text(s.openInGallery)),
                PopupMenuItem(value: 'share', child: Text(s.share)),
                PopupMenuItem(value: 'delete', child: Text(s.delete)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _play(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(record: record)));
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String action) async {
    final engine = ref.read(engineProvider);
    final uri = record.files.first.uri;
    final s = S.of(context);
    switch (action) {
      case 'play':
        _play(context);
      case 'open':
        await engine.open(uri);
      case 'share':
        await engine.share(uri);
      case 'delete':
        final deleteFiles = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.deleteQ),
            content: Text(s.deleteBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.listOnly)),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.deleteVideo)),
            ],
          ),
        );
        if (deleteFiles != null) {
          await ref.read(historyProvider.notifier).remove(record, deleteFiles: deleteFiles);
        }
    }
  }
}

String _formatSize(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}
