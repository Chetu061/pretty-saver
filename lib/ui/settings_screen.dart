import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/strings.dart';
import '../state/providers.dart';
import 'theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final appearance = ref.watch(appearanceProvider);
    final appearanceCtrl = ref.read(appearanceProvider.notifier);
    final engine = ref.watch(engineStatusProvider);
    final signedIn = ref.watch(accountProvider);
    final hasHistory = ref.watch(historyProvider).isNotEmpty;
    final textSizes = {0.9: s.small, 1.0: s.normal, 1.15: s.large};

    void snack(String text) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

    Future<void> fixDownloads() async {
      try {
        await ref.read(engineStatusProvider.notifier).update();
        snack(s.upToDate);
      } catch (_) {
        snack(s.updateFailed);
      }
    }

    Future<void> clearHistory() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.delete_sweep_outlined),
          title: Text(s.clearHistoryQ),
          content: Text(s.clearHistoryBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.clearBtn)),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(historyProvider.notifier).clear();
        snack(s.historyCleared);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Header(s.appearance),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(s.language),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final e in S.languages.entries) ButtonSegment(value: e.key, label: Text(e.value)),
              ],
              selected: {appearance.language},
              onSelectionChanged: (v) => appearanceCtrl.setLanguage(v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto), label: Text(s.themeSystem)),
                ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode), label: Text(s.themeLight)),
                ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode), label: Text(s.themeDark)),
              ],
              selected: {appearance.themeMode},
              onSelectionChanged: (v) => appearanceCtrl.setThemeMode(v.first),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: Text(s.font),
            trailing: Text(
              appearance.font == 'Default' ? s.fontDefault : appearance.font,
              style: fontPreview(appearance.font, const TextStyle(fontSize: 15)),
            ),
            onTap: () => _pickFont(context, ref, appearance.font),
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: Text(s.textSize),
            trailing: DropdownButton<double>(
              value: textSizes.containsKey(appearance.textScale) ? appearance.textScale : 1.0,
              underline: const SizedBox.shrink(),
              items: [
                for (final e in textSizes.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => appearanceCtrl.setTextScale(v ?? 1.0),
            ),
          ),
          // Sign-in itself is offered only from a failed download; here we just allow signing out.
          if (signedIn) ...[
            const Divider(),
            const _Header('Instagram'),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(s.signedIn),
              subtitle: Text(s.signOutHint),
              trailing: TextButton(
                onPressed: () => ref.read(accountProvider.notifier).signOut(),
                child: Text(s.signOut),
              ),
            ),
          ],
          const Divider(),
          _Header(s.downloads),
          ListTile(
            leading: const Icon(Icons.build_circle_outlined),
            title: Text(s.fixProblems),
            subtitle: Text(s.fixProblemsSub),
            trailing: engine.updating
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: engine.updating || !engine.ready ? null : fixDownloads,
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(s.clearHistory),
            subtitle: Text(s.clearHistorySub),
            enabled: hasHistory,
            onTap: clearHistory,
          ),
          const SizedBox(height: 24),
          Text(
            s.madeBy,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _pickFont(BuildContext context, WidgetRef ref, String current) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final font in appFonts)
              ListTile(
                title: Text(
                  font == 'Default' ? s.fontDefault : font,
                  style: fontPreview(font, const TextStyle(fontSize: 18)),
                ),
                trailing: font == current ? const Icon(Icons.check) : null,
                onTap: () {
                  ref.read(appearanceProvider.notifier).setFont(font);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
