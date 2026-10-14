import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/links.dart';
import '../l10n/strings.dart';
import '../state/providers.dart';
import 'history_tile.dart';
import 'how_to_guide.dart';
import 'settings_screen.dart';
import 'theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final engine = ref.read(engineProvider);
    // Share → Pretty Saver from Instagram downloads straight away.
    engine.onSharedText(_downloadShared);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(engineStatusProvider); // start unpacking yt-dlp in the background
      final shared = await engine.takeSharedText();
      if (shared != null) {
        _downloadShared(shared);
      } else {
        _fillFromClipboard();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fillFromClipboard();
  }

  /// Pre-fills the box when the user just copied a reel link in Instagram.
  Future<void> _fillFromClipboard() async {
    if (_controller.text.isNotEmpty || ref.read(downloadProvider) is Running) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) return;
    final link = checkLink(text);
    if (link is ValidLink && mounted) {
      setState(() => _controller.text = link.url);
    }
  }

  Future<void> _paste() async {
    final emptyMessage = S.of(context).clipboardEmpty;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _snack(emptyMessage);
      return;
    }
    final link = checkLink(text);
    setState(() => _controller.text = link is ValidLink ? link.url : text);
  }

  void _downloadShared(String text) {
    final link = checkLink(text);
    if (link is ValidLink) _controller.text = link.url;
    _download();
  }

  void _download() {
    FocusScope.of(context).unfocus();
    ref.read(downloadProvider.notifier).start(_controller.text);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(downloadProvider);
    final history = ref.watch(historyProvider);
    final running = phase is Running;
    final s = S.of(context);

    ref.listen(downloadProvider, (previous, next) {
      if (next is Done) {
        _controller.clear();
        _snack(S.of(context).savedSnack);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (rect) => brandGradient.createShader(rect),
          child: const Text('Pretty Saver', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        actions: [
          IconButton(
            tooltip: s.howToTitle,
            icon: const Icon(Icons.info_outline),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => const SafeArea(
                child: Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 16), child: HowToGuide()),
              ),
            ),
          ),
          IconButton(
            tooltip: s.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverList.list(
              children: [
                TextField(
                  controller: _controller,
                  enabled: !running,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _download(),
                  onChanged: (_) {
                    setState(() {}); // swap paste/clear icon
                    ref.read(downloadProvider.notifier).reset();
                  },
                  decoration: InputDecoration(
                    hintText: s.pasteHint,
                    helperText: s.publicOnlyHelper,
                    prefixIcon: const Icon(Icons.link),
                    suffixIcon: _controller.text.isEmpty
                        ? IconButton(tooltip: s.paste, icon: const Icon(Icons.content_paste), onPressed: running ? null : _paste)
                        : IconButton(
                            tooltip: s.clear,
                            icon: const Icon(Icons.close),
                            onPressed: running ? null : () => setState(_controller.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                _DownloadButton(running: running, onPressed: _download),
                const SizedBox(height: 16),
                _PhaseCard(phase: phase),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(s.downloads, style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          if (history.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: _EmptyHistory())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: history.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => HistoryTile(record: history[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.running, required this.onPressed});

  final bool running;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: running ? null : brandGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
        onPressed: running ? null : onPressed,
        icon: const Icon(Icons.download_rounded),
        label: Text(S.of(context).download, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _PhaseCard extends ConsumerWidget {
  const _PhaseCard({required this.phase});

  final DownloadPhase phase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = S.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (phase) {
        Idle() => const SizedBox.shrink(),
        Running(:final percent, :final status) => Card(
            key: const ValueKey('running'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(s.status(status), style: Theme.of(context).textTheme.titleSmall)),
                      if (percent > 0) Text('${percent.toStringAsFixed(0)}%'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(minHeight: 8, value: percent > 0 ? percent / 100 : null),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => ref.read(downloadProvider.notifier).cancel(),
                      child: Text(s.cancel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Done(:final record) => Card(
            key: ValueKey('done-${record.id}'),
            color: scheme.primaryContainer,
            child: ListTile(
              leading: Icon(Icons.check_circle, color: scheme.primary),
              title: Text(s.savedFrom(record.uploader)),
              subtitle: Text(
                record.files.length == 1 ? record.files.first.fileName : s.videosSaved(record.files.length),
              ),
            ),
          ),
        Failed(:final problem, :final details, :final retryUrl, :final needsSignIn) => Card(
            key: ValueKey('failed-$problem'),
            color: scheme.errorContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: Icon(Icons.error_outline, color: scheme.error),
                  title: Text(s.problem(problem), style: TextStyle(color: scheme.onErrorContainer)),
                ),
                if (needsSignIn && retryUrl != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.login),
                      label: Text(s.signInInstagram),
                      onPressed: () async {
                        if (await ref.read(accountProvider.notifier).signIn()) {
                          ref.read(downloadProvider.notifier).start(retryUrl);
                        }
                      },
                    ),
                  ),
                if (details != null) _ErrorDetails(details: details),
              ],
            ),
          ),
      },
    );
  }
}

class _ErrorDetails extends StatelessWidget {
  const _ErrorDetails({required this.details});

  final String details;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onErrorContainer;
    final s = S.of(context);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(s.details, style: TextStyle(color: color, fontSize: 14)),
        iconColor: color,
        collapsedIconColor: color,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: SelectableText(
                details,
                style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.copy, size: 18),
              label: Text(s.copy),
              style: TextButton.styleFrom(foregroundColor: color),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: details));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.detailsCopied)));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Card(
        child: Padding(padding: EdgeInsets.all(16), child: HowToGuide()),
      ),
    );
  }
}
