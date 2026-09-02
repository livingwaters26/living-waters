import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/bible_text_service.dart';
import '../services/simple_storage.dart';
import 'sessions_screen.dart';

/// Browse-only tree next to My MP3s. Does not replace the flat list.
/// Bible translations stay separate from Personal Readings / sermons.
class LibraryTreeScreen extends StatefulWidget {
  const LibraryTreeScreen({super.key});

  @override
  State<LibraryTreeScreen> createState() => _LibraryTreeScreenState();
}

class _LibraryTreeScreenState extends State<LibraryTreeScreen> {
  final _storage = SimpleStorage();
  final _bible = BibleTextService();
  List<AudioFile> _files = [];
  bool _loading = true;

  static const _personalNames = {
    'personal readings',
    'personal reading',
    'uncategorized',
    'sermons',
    'teaching',
    'teachings',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await _storage.loadAudioFiles();
    if (!mounted) return;
    setState(() {
      _files = files.where((f) => !f.path.startsWith('tts:')).toList();
      _loading = false;
    });
  }

  bool _isPersonal(AudioFile f) {
    final c = f.collection.trim().toLowerCase();
    if (_personalNames.contains(c)) return true;
    final book = _bible.findBookId(f.title);
    // No book in the title and no translation-looking folder → personal.
    if (book == null && !_looksLikeTranslation(c)) return true;
    return false;
  }

  bool _looksLikeTranslation(String collectionLower) {
    const tags = [
      'bsb',
      'berean',
      'esv',
      'kjv',
      'niv',
      'nasb',
      'nlt',
      'web',
      'asv',
      'nkjv',
      'csb',
      'msg',
    ];
    return tags.any((t) => collectionLower.contains(t));
  }

  String _translationLabel(AudioFile f) {
    final c = f.collection.trim();
    if (c.isEmpty) return 'Unknown translation';
    return c;
  }

  String _bookLabel(AudioFile f) {
    final id = _bible.findBookId(f.title);
    if (id != null) {
      return _bible.bookNameForId(id) ?? f.title;
    }
    return f.title;
  }

  @override
  Widget build(BuildContext context) {
    final personal = _files.where(_isPersonal).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    final bible = _files.where((f) => !_isPersonal(f)).toList();

    final byTranslation = <String, List<AudioFile>>{};
    for (final f in bible) {
      byTranslation.putIfAbsent(_translationLabel(f), () => []).add(f);
    }
    final translationNames = byTranslation.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Browse by book')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'This is a second view. My MP3s is still there if you need the old list.',
                  ),
                ),
                ExpansionTile(
                  key: const ValueKey('bible-root'),
                  initiallyExpanded: false,
                  leading: const Icon(Icons.menu_book),
                  title: const Text('Bible Translations'),
                  subtitle: Text('${bible.length} files'),
                  children: [
                    for (final name in translationNames)
                      _translationTile(name, byTranslation[name]!),
                  ],
                ),
                ExpansionTile(
                  key: const ValueKey('personal-root'),
                  initiallyExpanded: false,
                  leading: const Icon(Icons.mic),
                  title: const Text('Personal Readings'),
                  subtitle: Text('${personal.length} files'),
                  children: [
                    for (final f in personal) _fileTile(f),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _translationTile(String name, List<AudioFile> files) {
    final byBook = <String, List<AudioFile>>{};
    for (final f in files) {
      byBook.putIfAbsent(_bookLabel(f), () => []).add(f);
    }
    final books = byBook.keys.toList()..sort();
    return ExpansionTile(
      key: ValueKey('tr-$name'),
      initiallyExpanded: false,
      title: Text(name),
      subtitle: Text('${files.length} files'),
      children: [
        for (final book in books)
          ExpansionTile(
            key: ValueKey('book-$name-$book'),
            initiallyExpanded: false,
            title: Text(book),
            subtitle: Text('${byBook[book]!.length} files'),
            children: [
              for (final f in byBook[book]!) _fileTile(f),
            ],
          ),
      ],
    );
  }

  Widget _fileTile(AudioFile file) {
    return ListTile(
      title: Text(file.title),
      subtitle: Text(file.collection),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SessionsScreen(
              audioFileId: file.id,
              title: file.title,
            ),
          ),
        );
      },
    );
  }
}
