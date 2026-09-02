import 'package:flutter/material.dart';

import '../data/bible_episodes.dart';
import '../models/models.dart';
import '../services/bible_text_service.dart';
import '../services/drive_drama_service.dart';
import 'drama_tts_player_screen.dart';
import 'player_screen.dart';

class DriveDramaScreen extends StatefulWidget {
  const DriveDramaScreen({super.key});

  @override
  State<DriveDramaScreen> createState() => _DriveDramaScreenState();
}

class _DriveDramaScreenState extends State<DriveDramaScreen> {
  String? _selectedBook;
  final _bookFilter = TextEditingController();
  String _translation = 'bsb';

  bool _preparing = false;
  double _progress = 0;
  String _progressMessage = '';

  final _drama = DriveDramaService();
  Map<String, String> _translations = BibleTextService.translations;

  @override
  void initState() {
    super.initState();
    BibleTextService.allTranslations().then((m) {
      if (mounted) setState(() => _translations = m);
    });
  }

  @override
  void dispose() {
    _bookFilter.dispose();
    super.dispose();
  }

  List<String> get _books {
    final all = booksWithEpisodes(bookOrder: BibleTextService.bookOrder);
    final q = _bookFilter.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((b) => b.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedBook == null ? 'Drive Drama' : _selectedBook!),
        leading: _selectedBook != null && !_preparing
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedBook = null),
              )
            : null,
      ),
      body: SafeArea(
        child: _preparing
            ? _buildProgress()
            : (_selectedBook == null ? _buildBookPicker() : _buildEpisodeList()),
      ),
    );
  }

  Widget _buildProgress() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Preparing episode',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: 12),
          Text(_progressMessage, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Stay on Wi-Fi. Longer episodes can take several minutes.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildBookPicker() {
    final theme = Theme.of(context);
    final books = _books;
    final translations = _translations.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Choose a book. Episodes are about 30-45 minutes of dramatized listening.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in translations)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _translation == e.key,
                  onSelected: (_) => setState(() => _translation = e.key),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _bookFilter,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Filter books',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final book = books[index];
              final count = episodesForBook(book).length;
              final subtitle = '$count episodes';
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.auto_stories, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  title: Text(book, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(subtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _selectedBook = book),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeList() {
    final theme = Theme.of(context);
    final episodes = episodesForBook(_selectedBook!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Prepare downloads the episode, then saves it under My MP3s, Dramatization, book folder.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: episodes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ep = episodes[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ep.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text('${ep.rangeLabel}  ${ep.approxDuration}'),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => _prepare(ep),
                          icon: const Icon(Icons.download_for_offline),
                          label: const Text('Prepare episode'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _prepare(BibleEpisode ep) async {
    setState(() {
      _preparing = true;
      _progress = 0;
      _progressMessage = 'Starting';
    });
    try {
      final audio = await _drama.prepareEpisode(
        episode: ep,
        translation: _translation,
        onProgress: (p, msg) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            _progressMessage = msg;
          });
        },
      );
      if (!mounted) return;
      setState(() => _preparing = false);
      await _offerPlay(audio);
    } catch (e) {
      if (!mounted) return;
      setState(() => _preparing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not prepare episode: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _offerPlay(AudioFile audio) async {
    final message = '"' +
        audio.title +
        '" was saved under My MP3s to ' +
        audio.collection +
        '. You can play it offline from the library, or open it now.';
    final play = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Episode ready'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Play now'),
          ),
        ],
      ),
    );
    if (play == true && mounted) {
      if (DriveDramaService.isLiveTtsPath(audio.path)) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DramaTtsPlayerScreen(
              audioFileId: audio.id,
              title: audio.title,
            ),
          ),
        );
      } else {
        final sessionId = await _drama.sessionIdForAudio(audio.id) ?? audio.id;
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              audioFileId: audio.id,
              sessionId: sessionId,
              sessionLabel: audio.title,
              audioTitle: audio.title,
            ),
          ),
        );
      }
    }
  }
}
