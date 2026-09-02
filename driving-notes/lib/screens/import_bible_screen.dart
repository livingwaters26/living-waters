import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/bible_chunk_parser.dart';
import '../services/local_bible_store.dart';

/// Import scripture in ~300-page chunks under a version name.
/// Same version + same book/chapter/verse = duplicate (replaced).
/// Kings is never treated as Chronicles.
class ImportBibleScreen extends StatefulWidget {
  const ImportBibleScreen({super.key});

  @override
  State<ImportBibleScreen> createState() => _ImportBibleScreenState();
}

class _ImportBibleScreenState extends State<ImportBibleScreen> {
  final _nameController = TextEditingController();
  final _store = LocalBibleStore();
  final _parser = BibleChunkParser();

  List<LocalTranslationInfo> _existing = [];
  bool _busy = false;
  String _status = '';
  MergeReport? _lastReport;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final list = await _store.listTranslations();
    if (!mounted) return;
    setState(() => _existing = list);
  }

  Future<void> _importFiles() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a version name first, like NASB or ESV.')),
      );
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'text', 'json', 'usfm', 'md', 'pdf'],
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    setState(() {
      _busy = true;
      _status = 'Reading files…';
      _lastReport = null;
    });

    try {
      final all = <ParsedVerse>[];
      var fileDupes = 0;
      String lastHint = '';
      String lastSample = '';
      for (final f in picked.files) {
        final path = f.path;
        if (path == null) continue;
        setState(() => _status = 'Reading ${p.basename(path)}…');
        final bytes = await File(path).readAsBytes();
        final ext = p.extension(path).toLowerCase();
        final text = ext == '.pdf'
            ? BibleChunkParser.extractPdfText(bytes)
            : String.fromCharCodes(bytes);
        if (text.trim().isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No readable text in ${p.basename(path)}. Try a .txt export.')),
          );
          continue;
        }
        final parsed = _parser.parse(text);
        all.addAll(parsed.verses);
        fileDupes += parsed.duplicateInFile;
        if (parsed.verses.isEmpty && parsed.skippedHints.isNotEmpty) {
          lastHint = parsed.skippedHints.first;
          lastSample = parsed.sample;
        }
      }

      if (all.isEmpty) {
        setState(() {
          _busy = false;
          _status = 'No verses found.';
        });
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No verses found'),
            content: SingleChildScrollView(
              child: Text(
                lastHint.isNotEmpty
                    ? lastHint
                    : 'This file has no lines like Genesis 1:1 ...\n\nWhat the app could read:\n${lastSample.isEmpty ? "(nothing)" : lastSample}',
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
        return;
      }

      setState(() => _status = 'Checking against $name already on the device…');
      final preview = await _store.previewChunk(translationName: name, verses: all);
      if (!mounted) return;
      setState(() => _busy = false);

      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Import into $name?'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${preview.verseCount} verses detected:'),
                const SizedBox(height: 8),
                for (final line in preview.bookLines) Text('• $line'),
                const SizedBox(height: 12),
                Text(
                  'Overlap with what is already saved: '
                  '${preview.overlapMatched} matched'
                  '${preview.overlapMismatch == 0 ? '.' : ', ${preview.overlapMismatch} differ.'}',
                ),
                if (preview.overlapMismatch > 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Differing verses may be a parse mistake. '
                    'Kings and Chronicles are stored separately and will not overwrite each other.',
                  ),
                  for (final ref in preview.mismatchRefs) Text('  $ref'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancel')),
            if (preview.overlapMismatch > 0)
              TextButton(
                onPressed: () => Navigator.pop(context, 'replace'),
                child: const Text('Merge, replace diffs'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'keep'),
              child: const Text('Merge'),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel') {
        setState(() => _status = 'Cancelled — nothing saved.');
        return;
      }

      setState(() {
        _busy = true;
        _status = 'Merging into $name…';
      });
      final report = await _store.mergeChunk(
        translationName: name,
        verses: all,
        inFileDupes: fileDupes,
        replaceMismatches: choice == 'replace',
      );
      await _reload();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _lastReport = report;
        _status = 'Saved. Overlap matched ${report.overlapMatched}'
            '${report.overlapMismatch == 0 ? '.' : ', diffs ${report.overlapMismatch}.'}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Failed: $e';
      });
    }
  }

  Future<void> _delete(LocalTranslationInfo info) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${info.name}?'),
        content: const Text('Removes this imported translation from the device. Built-in KJV/BSB are not touched.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _store.deleteTranslation(info.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Import chunk')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Add your own translation in chunks (about 300 pages at a time). '
              'Use the same version name each time and the app merges. '
              'A duplicate is the same book, chapter, and verse — 1 Kings is never 1 Chronicles.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Version name',
                hintText: 'NASB',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in _existing)
                  ActionChip(
                    label: Text(t.name),
                    onPressed: () => _nameController.text = t.name,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _importFiles,
              icon: const Icon(Icons.upload_file),
              label: const Text('Pick files (txt or pdf)'),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (_status.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_status),
            ],
            if (_lastReport != null) ...[
              const SizedBox(height: 12),
              Text(
                'Added ${_lastReport!.added}, replaced ${_lastReport!.replaced}, '
                'already present ${_lastReport!.unchanged}. '
                'Same-verse repeats in this file: ${_lastReport!.inFileDupes}. '
                'Books touched: ${_lastReport!.booksTouched}.',
              ),
            ],
            const SizedBox(height: 24),
            Text('On this device', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_existing.isEmpty)
              const Text('None yet. Import a chunk to start a version.')
            else
              for (final t in _existing)
                Card(
                  child: ListTile(
                    title: Text(t.name),
                    subtitle: Text('${t.bookCount} books · ${t.verseCount} verses'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(t),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
