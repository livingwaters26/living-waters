import 'dart:io';

import 'package:flutter/material.dart';

import '../services/drive_drama_service.dart';
import '../services/tts_service.dart';

/// Plays a drive-drama script with on-device TTS when no wav file was created.
class DramaTtsPlayerScreen extends StatefulWidget {
  final String audioFileId;
  final String title;

  const DramaTtsPlayerScreen({
    super.key,
    required this.audioFileId,
    required this.title,
  });

  @override
  State<DramaTtsPlayerScreen> createState() => _DramaTtsPlayerScreenState();
}

class _DramaTtsPlayerScreenState extends State<DramaTtsPlayerScreen> {
  final _tts = TtsService();
  final _drama = DriveDramaService();

  List<String> _lines = [];
  int _index = 0;
  bool _loading = true;
  bool _playing = false;
  bool _stopped = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final path = await _drama.scriptPathForAudioId(widget.audioFileId);
      if (path == null || !await File(path).exists()) {
        setState(() {
          _loading = false;
          _error = 'Script file not found for this episode.';
        });
        return;
      }
      final text = await File(path).readAsString();
      final lines = text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      setState(() {
        _lines = lines;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _play() async {
    if (_playing || _lines.isEmpty) return;
    setState(() {
      _playing = true;
      _stopped = false;
    });
    for (var i = _index; i < _lines.length; i++) {
      if (_stopped || !mounted) break;
      setState(() => _index = i);
      await _tts.speak(DriveDramaService.spokenText(_lines[i]));
    }
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _stop() async {
    _stopped = true;
    await _tts.stop();
    if (mounted) setState(() => _playing = false);
  }

  @override
  void dispose() {
    _stopped = true;
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = (_lines.isNotEmpty && _index < _lines.length) ? _lines[_index] : '';

    return Scaffold(
      appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Live TTS · ${_index + 1} / ${_lines.length}',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                current.isEmpty ? 'Ready' : DriveDramaService.spokenText(current),
                                style: theme.textTheme.headlineSmall?.copyWith(height: 1.4),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: _playing ? null : _play,
                              icon: const Icon(Icons.play_arrow),
                              label: Text(_index > 0 && !_playing ? 'Resume' : 'Play'),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton.icon(
                              onPressed: _playing ? _stop : null,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Uses your device voice. Offline after the episode was prepared.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
